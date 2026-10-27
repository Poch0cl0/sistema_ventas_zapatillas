import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
  Optional,
  BadRequestException,
} from '@nestjs/common';
import { FieldValue, Timestamp, FieldPath } from 'firebase-admin/firestore';
import { OrderQueryDto, dateBounds } from './dto/order-query.dto.js';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import { firestorePage } from '../common/firestore-page.js';
import {
  orderView,
  expired,
  requireOpen,
  RESERVATION_MS,
  settleInventory,
} from './order-state.js';
import { DeliveryType, FulfillmentStatus } from './dto/order.dto.js';
import type { CreateOrderDto } from './dto/order.dto.js';
import { ConfigService } from '@nestjs/config';

export const hash = (value: string) =>
  createHash('sha256').update(value).digest('hex');

@Injectable()
export class OrdersRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
    @Optional() @Inject(ConfigService) private readonly config?: ConfigService,
  ) {}

  async create(input: CreateOrderDto, uid: string, key: string) {
    const id = hash(`${uid}:${key}`);
    const fingerprint = hash(JSON.stringify(input));
    const ref = this.firestore.collection('orders').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists) {
        if (existing.data()!.fingerprint !== fingerprint)
          throw new ConflictException(
            'La clave de idempotencia ya se usó con otros datos.',
          );
        return orderView(id, existing.data()!);
      }
      const settingsRef = this.firestore
        .collection('store_settings')
        .doc('main');
      const productRefs = input.items.map((item) =>
        this.firestore.collection('products').doc(item.productId),
      );
      const inventoryRefs = input.items.map((item) =>
        this.firestore
          .collection('inventory')
          .doc(`${item.productId}_${item.size}`),
      );
      const zoneRef =
        input.delivery.type === DeliveryType.DELIVERY
          ? this.firestore
              .collection('delivery_zones')
              .doc(input.delivery.zoneId!)
          : null;
      const settings = await transaction.get(settingsRef);
      const products = await transaction.getAll(...productRefs);
      const inventory = await transaction.getAll(...inventoryRefs);
      const zone = zoneRef ? await transaction.get(zoneRef) : null;
      if (!settings.exists)
        throw new ConflictException('La tienda aún no está configurada.');
      let delivery: DocumentData = {
        type: input.delivery.type,
        recipientName: input.delivery.recipientName,
        phone: input.delivery.phone,
      };
      let deliveryFeeCents = 0;
      if (zoneRef) {
        if (!zone?.exists || zone.data()!.active !== true)
          throw new ConflictException('La zona de delivery no está activa.');
        deliveryFeeCents = zone.data()!.feeCents;
        if (!Number.isSafeInteger(deliveryFeeCents) || deliveryFeeCents < 0)
          throw new ConflictException('Tarifa inválida.');
        delivery = {
          ...delivery,
          zoneId: zoneRef.id,
          zoneName: zone.data()!.name,
          address: input.delivery.address,
          ...(input.delivery.clientLat !== undefined &&
          input.delivery.clientLon !== undefined
            ? {
                clientLat: input.delivery.clientLat,
                clientLon: input.delivery.clientLon,
              }
            : {}),
          reference: input.delivery.reference ?? null,
          feeCents: deliveryFeeCents,
          ...this.originSnapshot(zone.data()!),
        };
      } else {
        const pickup = settings.data()!.pickup;
        if (pickup?.enabled !== true)
          throw new ConflictException(
            'El recojo en tienda no está habilitado.',
          );
        delivery = {
          ...delivery,
          pickupAddress: pickup.address,
          pickupInstructions: pickup.instructions,
          pickupOpeningHours: pickup.openingHours,
          feeCents: 0,
        };
      }
      const items = input.items.map((item, index) => {
        const product = products[index].data();
        const stock = inventory[index].data();
        if (!product || product.active !== true || !stock)
          throw new ConflictException('Producto o talla no disponible.');
        if (
          !Number.isSafeInteger(product.priceCents) ||
          product.priceCents < 0 ||
          !Number.isSafeInteger(stock.available) ||
          !Number.isSafeInteger(stock.reserved) ||
          stock.reserved < 0 ||
          stock.available < item.quantity
        )
          throw new ConflictException(
            'Stock insuficiente o datos inconsistentes.',
          );
        return {
          productId: item.productId,
          name: product.name,
          size: item.size,
          quantity: item.quantity,
          unitPriceCents: product.priceCents,
        };
      });
      const subtotalCents = items.reduce(
        (sum, item) => sum + item.unitPriceCents * item.quantity,
        0,
      );
      const totalCents = subtotalCents + deliveryFeeCents;
      if (!Number.isSafeInteger(totalCents) || totalCents > 100000000)
        throw new ConflictException('El total excede el límite permitido.');
      const createdAt = Timestamp.now();
      const reservationExpiresAt = Timestamp.fromMillis(
        createdAt.toMillis() + RESERVATION_MS,
      );
      const data = {
        userId: uid,
        fingerprint,
        items,
        subtotalCents,
        deliveryFeeCents,
        totalCents,
        currency: 'PEN',
        isSimulation:
          this.config?.get<string>('CHECKOUT_SIMULATION_ENABLED') === 'true',
        delivery,
        status: 'PENDIENTE_PAGO',
        paymentStatus: 'PENDIENTE',
        fulfillmentStatus: 'SIN_INICIAR',
        reservationState: 'ACTIVE',
        reservationExpiresAt,
        reservationDueAt: reservationExpiresAt,
        createdAt,
        updatedAt: createdAt,
      };
      transaction.create(ref, data);
      inventory.forEach((snapshot, index) => {
        const stock = snapshot.data()!;
        const item = items[index];
        transaction.update(inventoryRefs[index], {
          available: stock.available - item.quantity,
          reserved: stock.reserved + item.quantity,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(
          this.firestore.collection('inventory_movements').doc(),
          {
            inventoryId: snapshot.id,
            productId: item.productId,
            size: item.size,
            orderId: id,
            type: 'RESERVA',
            delta: -item.quantity,
            reservedDelta: item.quantity,
            availableBefore: stock.available,
            availableAfter: stock.available - item.quantity,
            reservedBefore: stock.reserved,
            reservedAfter: stock.reserved + item.quantity,
            actorId: uid,
            reason: 'Reserva de pedido online',
            createdAt,
          },
        );
      });
      return orderView(id, data);
    });
  }

  async list(pagination: OrderQueryDto, uid?: string) {
    const collection = this.firestore.collection('orders');
    const bounds = dateBounds(pagination);
    if (pagination.from || pagination.to) {
      let query = uid ? collection.where('userId', '==', uid) : collection;
      if (bounds.from !== undefined)
        query = query.where(
          'createdAt',
          '>=',
          Timestamp.fromMillis(bounds.from),
        );
      if (bounds.to !== undefined)
        query = query.where('createdAt', '<', Timestamp.fromMillis(bounds.to));
      let ordered = query
        .orderBy('createdAt', 'desc')
        .orderBy(FieldPath.documentId(), 'desc');
      if (pagination.after) {
        const cursor = await collection.doc(pagination.after).get();
        if (!cursor.exists)
          throw new BadRequestException('Cursor de pedidos inválido.');
        ordered = ordered.startAfter(cursor);
      }
      const snapshot = await ordered.limit(pagination.limit + 1).get();
      const docs = snapshot.docs.slice(0, pagination.limit);
      return {
        items: docs.map((doc) => orderView(doc.id, doc.data())),
        nextCursor: snapshot.size > pagination.limit ? docs.at(-1)!.id : null,
      };
    }
    const result = await firestorePage(
      uid ? collection.where('userId', '==', uid) : collection,
      pagination,
    );
    return {
      items: result.docs.map((doc) => orderView(doc.id, doc.data())),
      nextCursor: result.nextCursor,
    };
  }

  private originSnapshot(zone: DocumentData) {
    const lat =
      typeof zone.originLat === 'number'
        ? zone.originLat
        : Number(this.config?.get('ORS_STORE_LAT'));
    const lon =
      typeof zone.originLon === 'number'
        ? zone.originLon
        : Number(this.config?.get('ORS_STORE_LON'));
    return Number.isFinite(lat) &&
      Number.isFinite(lon) &&
      Math.abs(lat) <= 90 &&
      Math.abs(lon) <= 180
      ? { originLat: lat, originLon: lon }
      : {};
  }

  async completeSimulation(id: string, uid: string, action: 'PAY' | 'SKIP') {
    const ref = this.firestore.collection('orders').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()!.userId !== uid)
        throw new NotFoundException('Pedido no encontrado.');
      const order = snapshot.data()!;
      if (
        order.isSimulation === true &&
        order.reservationState === 'CONSUMED' &&
        ['SIMULADO', 'NO_REQUERIDO'].includes(order.paymentStatus)
      ) {
        if (action === 'PAY' && order.paymentStatus === 'NO_REQUERIDO') {
          const changes = {
            status: 'ENTREGADO',
            fulfillmentStatus: 'ENTREGADO',
            paymentStatus: 'SIMULADO',
            simulationCompletedAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          };
          transaction.update(ref, changes);
          return orderView(id, { ...order, ...changes });
        }
        return orderView(id, order);
      }
      requireOpen(order);
      if (expired(order))
        throw new ConflictException('La reserva venció. Crea un pedido nuevo.');
      if (
        order.currentPaymentId ||
        order.paymentStatus === 'PENDIENTE_VERIFICACION'
      )
        throw new ConflictException(
          'Este pedido ya tiene una referencia de pago manual y debe revisarla el administrador.',
        );
      const refs = order.items.map(
        (item: { productId: string; size: string }) =>
          this.firestore
            .collection('inventory')
            .doc(`${item.productId}_${item.size}`),
      );
      await settleInventory(
        transaction,
        { ...order, id },
        refs,
        refs.map(() => this.firestore.collection('inventory_movements').doc()),
        uid,
        false,
        action,
      );
      const changes = {
        isSimulation: true,
        status: action === 'PAY' ? 'ENTREGADO' : 'CONFIRMADO_SIN_PAGO',
        paymentStatus: action === 'PAY' ? 'SIMULADO' : 'NO_REQUERIDO',
        fulfillmentStatus: action === 'PAY' ? 'ENTREGADO' : 'PREPARANDO',
        reservationState: 'CONSUMED',
        reservationDueAt: FieldValue.delete(),
        simulationCompletedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      };
      transaction.update(ref, changes);
      return orderView(id, { ...order, ...changes });
    });
  }

  async find(id: string, uid?: string) {
    const snapshot = await this.firestore.collection('orders').doc(id).get();
    if (!snapshot.exists || (uid && snapshot.data()!.userId !== uid))
      throw new NotFoundException('Pedido no encontrado.');
    return orderView(id, snapshot.data()!);
  }

  async cancel(id: string, uid: string) {
    const ref = this.firestore.collection('orders').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()!.userId !== uid)
        throw new NotFoundException('Pedido no encontrado.');
      const order = snapshot.data()!;
      if (order.status === 'CANCELADO') return orderView(id, order);
      requireOpen(order);
      const paymentRef = order.currentPaymentId
        ? this.firestore.collection('payments').doc(order.currentPaymentId)
        : null;
      const payment = paymentRef ? await transaction.get(paymentRef) : null;
      const refs = order.items.map(
        (item: { productId: string; size: string }) =>
          this.firestore
            .collection('inventory')
            .doc(`${item.productId}_${item.size}`),
      );
      await settleInventory(
        transaction,
        { ...order, id },
        refs,
        refs.map(() => this.firestore.collection('inventory_movements').doc()),
        uid,
        true,
      );
      const changes = {
        status: 'CANCELADO',
        paymentStatus: expired(order) ? 'VENCIDO' : 'CANCELADO',
        reservationState: 'RELEASED',
        reservationDueAt: FieldValue.delete(),
        cancellationReason: expired(order) ? 'RESERVA_VENCIDA' : 'CLIENTE',
        cancelledAt: FieldValue.serverTimestamp(),
        cancelledBy: uid,
        updatedAt: FieldValue.serverTimestamp(),
      };
      transaction.update(ref, changes);
      if (
        paymentRef &&
        payment?.exists &&
        payment.data()!.status === 'PENDIENTE_VERIFICACION'
      )
        transaction.update(paymentRef, {
          status: 'CANCELADO',
          updatedAt: FieldValue.serverTimestamp(),
        });
      return orderView(id, { ...order, ...changes });
    });
  }

  async fulfillment(id: string, status: FulfillmentStatus, actorId: string) {
    const ref = this.firestore.collection('orders').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists)
        throw new NotFoundException('Pedido no encontrado.');
      const data = snapshot.data()!;
      if (
        data.paymentStatus !== 'APROBADO' &&
        !(
          data.isSimulation === true &&
          ['SIMULADO', 'NO_REQUERIDO'].includes(data.paymentStatus)
        )
      )
        throw new ConflictException('El pago debe estar aprobado.');
      if (data.fulfillmentStatus === status) return orderView(id, data);
      const ready =
        data.delivery.type === 'PICKUP' ? 'LISTO_RECOJO' : 'EN_REPARTO';
      const next =
        data.fulfillmentStatus === 'PREPARANDO'
          ? ready
          : data.fulfillmentStatus === ready
            ? 'ENTREGADO'
            : null;
      if (next !== status)
        throw new ConflictException('Transición logística no permitida.');
      const changes = {
        fulfillmentStatus: status,
        updatedAt: FieldValue.serverTimestamp(),
        fulfillmentUpdatedBy: actorId,
      };
      transaction.update(ref, changes);
      return orderView(id, { ...data, ...changes });
    });
  }
}
