import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/app_failure.dart';
import '../store/store_repository.dart';

class DeliveryLocation {
  const DeliveryLocation({required this.lat, required this.lon});
  final double lat, lon;
  LatLng get point => LatLng(lat, lon);
  String get label => '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  Json get json => {'clientLat': lat, 'clientLon': lon};
  static DeliveryLocation? fromDelivery(Json delivery) {
    final lat = delivery['clientLat'], lon = delivery['clientLon'];
    if (lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180)
      return null;
    return DeliveryLocation(lat: lat.toDouble(), lon: lon.toDouble());
  }

  static DeliveryLocation? originFrom(Json value) => fromDelivery({
    'clientLat': value['originLat'],
    'clientLon': value['originLon'],
  });
}

class DeliveryMapConfig {
  const DeliveryMapConfig(
    this.store,
    this.tileUrl,
    this.attribution,
    this.routingEnabled,
  );
  final LatLng store;
  final String tileUrl, attribution;
  final bool routingEnabled;
  factory DeliveryMapConfig.fromJson(Json json) {
    final store = Json.from(json['store'] as Map);
    final lat = store['lat'], lon = store['lon'];
    final tileUrl = json['tileUrl'] as String;
    if (lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        Uri.tryParse(tileUrl)?.scheme != 'https') {
      throw const AppFailure(
        'La configuración del mapa no es válida. Contacta con la tienda.',
      );
    }
    return DeliveryMapConfig(
      LatLng(lat.toDouble(), lon.toDouble()),
      tileUrl,
      json['tileAttribution'] as String,
      json['routingEnabled'] == true,
    );
  }
}

class DeliveryRoute {
  const DeliveryRoute(this.points, this.distance, this.duration, {this.origin});
  final List<LatLng> points;
  final double distance, duration;
  final LatLng? origin;
  factory DeliveryRoute.fromJson(Json json) {
    final geometry = Json.from(json['geometry'] as Map);
    if (geometry['type'] != 'LineString')
      throw const AppFailure('La ruta recibida no es válida.');
    final points = (geometry['coordinates'] as List).map((e) {
      final p = e as List;
      // GeoJSON and ORS use longitude first; Flutter's LatLng uses latitude first.
      return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
    }).toList();
    if (points.length < 2)
      throw const AppFailure('No encontramos un recorrido para este destino.');
    final origin = json['origin'] is Map
        ? Json.from(json['origin'] as Map)
        : null;
    return DeliveryRoute(
      points,
      (json['distance'] as num).toDouble(),
      (json['duration'] as num).toDouble(),
      origin: origin == null
          ? null
          : LatLng(
              (origin['lat'] as num).toDouble(),
              (origin['lon'] as num).toDouble(),
            ),
    );
  }
}

class DeliveryRepository {
  DeliveryRepository(this.store);
  final StoreRepository store;
  Future<DeliveryMapConfig> config() async =>
      DeliveryMapConfig.fromJson(await store.get('/api/delivery/config'));
  Future<DeliveryRoute> route(
    DeliveryLocation destination, {
    String? zoneId,
    String? orderId,
  }) async => DeliveryRoute.fromJson(
    await store.write(
      'POST',
      '/api/delivery/route',
      data: {
        ...destination.json,
        if (zoneId != null) 'zoneId': zoneId,
        if (orderId != null) 'orderId': orderId,
      },
    ),
  );
}

final deliveryRepositoryProvider = Provider(
  (ref) => DeliveryRepository(ref.watch(storeRepositoryProvider)),
);
