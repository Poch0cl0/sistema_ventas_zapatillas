import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { isAxiosError } from 'axios';
import type { DeliveryRouteDto } from './dto/delivery-route.dto.js';
import type { Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';

type RouteResult = {
  geometry: { type: 'LineString'; coordinates: number[][] };
  distance: number;
  duration: number;
  origin: { lat: number; lon: number };
};
const object = (value: unknown): Record<string, unknown> | undefined =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;

@Injectable()
export class DeliveryService {
  private readonly cache = new Map<
    string,
    { expires: number; value: RouteResult }
  >();
  private readonly budgets = new Map<
    string,
    { expires: number; count: number }
  >();
  private active = 0;
  constructor(
    @Inject(ConfigService) private readonly config: ConfigService,
    @Inject(HttpService) private readonly http: HttpService,
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  publicConfig() {
    const latValue = this.config.get<string>('ORS_STORE_LAT');
    const lonValue = this.config.get<string>('ORS_STORE_LON');
    const lat = Number(latValue),
      lon = Number(lonValue);
    if (
      !latValue?.trim() ||
      !lonValue?.trim() ||
      !Number.isFinite(lat) ||
      !Number.isFinite(lon) ||
      Math.abs(lat) > 90 ||
      Math.abs(lon) > 180
    ) {
      throw new ServiceUnavailableException(
        'La tienda todavía no configuró una ubicación válida para el mapa.',
      );
    }
    return {
      store: { lat, lon },
      profile: 'driving-car',
      routingEnabled: Boolean(this.config.get<string>('ORS_API_KEY')?.trim()),
      tileUrl:
        this.config.get<string>('MAP_TILE_URL') ??
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      tileAttribution:
        this.config.get<string>('MAP_TILE_ATTRIBUTION') ??
        '© OpenStreetMap contributors · openstreetmap.org/copyright',
    };
  }

  async route(
    input: DeliveryRouteDto,
    uid: string,
    admin = false,
  ): Promise<RouteResult> {
    let { store } = this.publicConfig();
    let clientLat = input.clientLat,
      clientLon = input.clientLon;
    if (input.orderId) {
      const snapshot = await this.firestore
        .collection('orders')
        .doc(input.orderId)
        .get();
      if (!snapshot.exists || (!admin && snapshot.data()!.userId !== uid))
        throw new NotFoundException('Pedido no encontrado.');
      const delivery = snapshot.data()!.delivery;
      if (
        delivery?.type !== 'DELIVERY' ||
        typeof delivery.clientLat !== 'number' ||
        typeof delivery.clientLon !== 'number'
      )
        throw new BadRequestException(
          'El pedido no tiene un destino guardado en el mapa.',
        );
      clientLat = delivery.clientLat;
      clientLon = delivery.clientLon;
      if (
        typeof delivery.originLat === 'number' &&
        typeof delivery.originLon === 'number'
      )
        store = { lat: delivery.originLat, lon: delivery.originLon };
    } else if (input.zoneId) {
      const snapshot = await this.firestore
        .collection('delivery_zones')
        .doc(input.zoneId)
        .get();
      if (!snapshot.exists || snapshot.data()!.active !== true)
        throw new BadRequestException('La zona de entrega ya no está activa.');
      const zone = snapshot.data()!;
      if (
        typeof zone.originLat === 'number' &&
        typeof zone.originLon === 'number'
      )
        store = { lat: zone.originLat, lon: zone.originLon };
    }
    const apiKey = this.config.get<string>('ORS_API_KEY')?.trim();
    if (!apiKey)
      throw new ServiceUnavailableException(
        'La tienda todavía no habilitó el cálculo de rutas.',
      );
    // Never allow the API key to be sent to a configurable third-party host.
    const base = (
      this.config.get<string>('ORS_BASE_URL') ?? 'https://api.heigit.org'
    ).replace(/\/+$/, '');
    if (base !== 'https://api.heigit.org') {
      throw new ServiceUnavailableException(
        'La dirección del servicio de rutas no está configurada correctamente.',
      );
    }
    const now = Date.now();
    for (const [key, entry] of this.budgets)
      if (entry.expires <= now) this.budgets.delete(key);
    const budget = this.budgets.get(uid) ?? { expires: now + 60000, count: 0 };
    if (
      budget.count >= 12 ||
      (!this.budgets.has(uid) && this.budgets.size >= 1000)
    ) {
      throw new HttpException(
        'Demasiados cálculos de ruta. Espera un minuto y vuelve a intentarlo.',
        429,
      );
    }
    budget.count++;
    this.budgets.set(uid, budget);
    for (const [key, entry] of this.cache)
      if (entry.expires <= now) this.cache.delete(key);
    const key = `${store.lon},${store.lat}:${clientLon},${clientLat}`;
    const cached = this.cache.get(key);
    if (cached) return cached.value;
    if (this.active >= 8)
      throw new HttpException(
        'El servicio de rutas está ocupado. Inténtalo en unos segundos.',
        429,
      );
    this.active++;
    try {
      const response = await this.http.axiosRef.post<unknown>(
        `${base}/openrouteservice/v2/directions/driving-car/geojson`,
        {
          coordinates: [
            [store.lon, store.lat],
            [clientLon, clientLat],
          ],
        },
        {
          headers: {
            Authorization: apiKey,
            'Content-Type': 'application/json',
            Accept: 'application/geo+json',
          },
        },
      );
      const data = object(response.data);
      const feature = Array.isArray(data?.features)
        ? object(data.features[0])
        : undefined;
      const geometry = object(feature?.geometry);
      const summary = object(object(feature?.properties)?.summary);
      const distance = summary?.distance;
      const duration = summary?.duration;
      const coordinates = geometry?.coordinates;
      if (
        geometry?.type !== 'LineString' ||
        !Array.isArray(coordinates) ||
        coordinates.length < 2 ||
        coordinates.length > 50000 ||
        !coordinates.every(
          (point: unknown) =>
            Array.isArray(point) &&
            point.length >= 2 &&
            typeof point[0] === 'number' &&
            typeof point[1] === 'number' &&
            Number.isFinite(point[0]) &&
            Number.isFinite(point[1]) &&
            Math.abs(point[0]) <= 180 &&
            Math.abs(point[1]) <= 90,
        ) ||
        typeof distance !== 'number' ||
        !Number.isFinite(distance) ||
        distance < 0 ||
        typeof duration !== 'number' ||
        !Number.isFinite(duration) ||
        duration < 0
      ) {
        throw new BadGatewayException(
          'El proveedor devolvió una ruta inválida. Inténtalo nuevamente.',
        );
      }
      const result: RouteResult = {
        geometry: {
          type: 'LineString',
          coordinates: (coordinates as number[][]).map((p) => [p[0], p[1]]),
        },
        distance,
        duration,
        origin: store,
      };
      if (this.cache.size >= 100)
        this.cache.delete(this.cache.keys().next().value!);
      this.cache.set(key, { expires: now + 5 * 60000, value: result });
      return result;
    } catch (error) {
      if (error instanceof HttpException) throw error;
      if (isAxiosError(error)) {
        const status = error.response?.status;
        if (status === 429)
          throw new HttpException(
            'Se alcanzó el límite del proveedor de rutas. Inténtalo más tarde.',
            429,
          );
        if (status === 401 || status === 403)
          throw new ServiceUnavailableException(
            'El proveedor no autorizó el cálculo de rutas. La tienda debe revisar la clave y los permisos ORS.',
          );
        if ([400, 404, 422].includes(status ?? 0))
          throw new BadRequestException(
            'No se encontró una ruta para ese punto. Selecciona una ubicación cercana a una calle accesible.',
          );
      }
      // Do not log or forward Axios errors: their request headers contain the key.
      throw new ServiceUnavailableException(
        'No pudimos conectar con el servicio de rutas. Puedes conservar el punto seleccionado e intentarlo más tarde.',
      );
    } finally {
      this.active--;
    }
  }
}
