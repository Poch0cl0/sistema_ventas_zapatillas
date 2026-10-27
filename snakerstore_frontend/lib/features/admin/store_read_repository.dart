import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_page.dart';
import '../../core/network/app_failure.dart';
import '../auth/application/session.dart';
import '../store/store_repository.dart';

// Compact list models; detail screens load the full resource before a mutation.
class StoreEntry {
  const StoreEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    this.amountCents,
    this.status,
    this.data = const {},
  });
  final String id, title, subtitle;
  final int? amountCents;
  final String? status;
  final Map<String, dynamic> data;
  factory StoreEntry.order(Map<String, dynamic> json) => StoreEntry(
    data: json,
    id: json['id'] as String,
    title: json['id'] as String,
    subtitle: (json['items'] as List<dynamic>)
        .map((item) {
          final value = item as Map;
          return '${value['name']} · EU ${value['size']} × ${value['quantity']}';
        })
        .join('\n'),
    amountCents: json['totalCents'] as int,
    status: '${json['paymentStatus']} · ${json['fulfillmentStatus']}',
  );
  factory StoreEntry.inventory(Map<String, dynamic> json) => StoreEntry(
    data: json,
    id: json['id'] as String,
    title: '${json['productId']} · EU ${json['size']}',
    subtitle:
        '${json['available']} disponibles · ${json['reserved']} reservadas',
  );
  factory StoreEntry.zone(Map<String, dynamic> json) => StoreEntry(
    data: json,
    id: json['id'] as String,
    title: json['name'] as String,
    subtitle: json['active'] == true ? 'Activa' : 'Inactiva',
    amountCents: json['feeCents'] as int,
  );
}

class StoreReadRepository {
  StoreReadRepository(this.api);
  final Dio api;
  Future<ApiPage<StoreEntry>> list(String path, String? after) async {
    final uri = Uri.parse(path);
    final response = await api.get<Map<String, dynamic>>(
      uri.path,
      queryParameters: {...uri.queryParameters, 'limit': 20, 'after': ?after},
    );
    return ApiPage.fromJson(
      response.data!,
      path.endsWith('inventory')
          ? StoreEntry.inventory
          : path.endsWith('delivery-zones')
          ? StoreEntry.zone
          : StoreEntry.order,
    );
  }
}

final storeReadRepositoryProvider = Provider(
  (ref) => StoreReadRepository(ref.watch(apiClientProvider)),
);
typedef StoreReadQuery = ({String path, String? after});
final storePageProvider = FutureProvider.autoDispose
    .family<ApiPage<StoreEntry>, StoreReadQuery>((ref, query) {
      final profile = ref.watch(sessionProvider).profile;
      if (profile == null ||
          (query.path.startsWith('/admin/') && !profile.isAdmin)) {
        throw const AppFailure(
          'No tienes permiso para acceder a esta sección.',
        );
      }
      return ref
          .watch(storeReadRepositoryProvider)
          .list(query.path, query.after);
    });

typedef AdminOverview = ({
  List<Json> products,
  List<Json> inventory,
  List<Json> orders,
  List<Json> zones,
});
final adminOverviewProvider = FutureProvider.autoDispose<AdminOverview>((
  ref,
) async {
  if (ref.watch(sessionProvider).profile?.isAdmin != true)
    throw const AppFailure('Acceso administrativo requerido.');
  final repo = ref.watch(storeRepositoryProvider);
  final results = await Future.wait([
    repo.all('/admin/products'),
    repo.all('/admin/inventory'),
    repo.all('/admin/orders'),
    repo.all('/admin/delivery-zones'),
  ]);
  return (
    products: results[0],
    inventory: results[1],
    orders: results[2],
    zones: results[3],
  );
});
