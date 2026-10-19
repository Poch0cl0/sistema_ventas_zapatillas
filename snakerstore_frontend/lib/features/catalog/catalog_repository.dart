import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_page.dart';
import '../../core/network/app_failure.dart';
import '../auth/application/session.dart';

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.description,
    required this.priceCents,
    required this.active,
    required this.images,
    this.modelUrl,
  });
  final String id, name, brand, category, description;
  final int priceCents;
  final bool active;
  final List<String> images;
  final String? modelUrl;
  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    priceCents: json['priceCents'] as int,
    active: json['active'] as bool,
    modelUrl:
        json['model3d'] is Map &&
            (json['model3d'] as Map)['format'] == 'glb' &&
            Uri.tryParse('${(json['model3d'] as Map)['secure_url']}')?.scheme ==
                'https'
        ? (json['model3d'] as Map)['secure_url'] as String
        : null,
    images: (json['images'] as List<dynamic>? ?? [])
        .map((image) => (image as Map)['secure_url'])
        .whereType<String>()
        .where((url) => Uri.tryParse(url)?.scheme == 'https')
        .toList(),
  );
}

class CatalogRepository {
  CatalogRepository(this.api);
  final Dio api;
  Future<ApiPage<CatalogProduct>> list({
    bool admin = false,
    String? after,
  }) async {
    final response = await api.get<Map<String, dynamic>>(
      admin ? '/admin/products' : '/products',
      queryParameters: {'limit': 20, 'after': ?after},
      options: Options(extra: {'authenticated': admin}),
    );
    return ApiPage.fromJson(response.data!, CatalogProduct.fromJson);
  }

  Future<CatalogProduct> find(String id, {bool admin = false}) async {
    final response = await api.get<Map<String, dynamic>>(
      '${admin ? '/admin/products' : '/products'}/${Uri.encodeComponent(id)}',
      options: Options(extra: {'authenticated': admin}),
    );
    return CatalogProduct.fromJson(response.data!);
  }
}

final catalogRepositoryProvider = Provider(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
);
typedef CatalogQuery = ({bool admin, String? after});
final catalogPageProvider = FutureProvider.autoDispose
    .family<ApiPage<CatalogProduct>, CatalogQuery>((ref, query) {
      if (query.admin && ref.watch(sessionProvider).profile?.isAdmin != true) {
        throw const AppFailure('Inicia sesión como administrador.');
      }
      return ref
          .watch(catalogRepositoryProvider)
          .list(admin: query.admin, after: query.after);
    });
typedef ProductQuery = ({bool admin, String id});
final catalogProductProvider = FutureProvider.autoDispose
    .family<CatalogProduct, ProductQuery>((ref, query) {
      if (query.admin && ref.watch(sessionProvider).profile?.isAdmin != true) {
        throw const AppFailure('Inicia sesión como administrador.');
      }
      return ref
          .watch(catalogRepositoryProvider)
          .find(query.id, admin: query.admin);
    });
