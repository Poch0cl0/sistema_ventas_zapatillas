import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../auth/application/session.dart';
import '../catalog/catalog_repository.dart';
import '../../core/network/app_failure.dart';

typedef Json = Map<String, dynamic>;

class StoreRepository {
  StoreRepository(this.api);
  final Dio api;
  Future<Json> get(String path, {bool public = false}) async =>
      (await api.get<Json>(
        path,
        options: Options(extra: {'authenticated': !public}),
      )).data!;
  Future<List<Json>> all(String path, {bool public = false}) async {
    final result = <Json>[];
    String? after;
    do {
      final page = (await api.get<Json>(
        path,
        queryParameters: {'limit': 100, 'after': ?after},
        options: Options(extra: {'authenticated': !public}),
      )).data!;
      result.addAll((page['items'] as List).map((e) => Json.from(e as Map)));
      after = page['nextCursor'] as String?;
    } while (after != null);
    return result;
  }

  Future<Json> write(
    String method,
    String path, {
    Object? data,
    String? key,
  }) async => (await api.request<Json>(
    path,
    data: data,
    options: Options(
      method: method,
      sendTimeout: path.endsWith('/model')
          ? const Duration(seconds: 120)
          : null,
      receiveTimeout: path.endsWith('/model')
          ? const Duration(seconds: 120)
          : path.endsWith('/simulation') || path.endsWith('/receipt/send')
          ? const Duration(seconds: 60)
          : null,
      headers: {if (key != null) 'Idempotency-Key': key},
    ),
  )).data!;
  Future<List<Json>> availability(String id) async =>
      ((await api.get<List<dynamic>>(
        '/products/${Uri.encodeComponent(id)}/availability',
        options: Options(extra: {'authenticated': false}),
      )).data!).map((e) => Json.from(e as Map)).toList();
}

final storeRepositoryProvider = Provider(
  (ref) => StoreRepository(ref.watch(apiClientProvider)),
);
final checkoutOptionsProvider = FutureProvider.autoDispose<Json>(
  (ref) =>
      ref.watch(storeRepositoryProvider).get('/checkout-options', public: true),
);
final availabilityProvider = FutureProvider.autoDispose
    .family<List<Json>, String>(
      (ref, id) => ref.watch(storeRepositoryProvider).availability(id),
    );
final storeDocumentProvider = FutureProvider.autoDispose.family<Json, String>((
  ref,
  path,
) {
  ref.watch(sessionProvider.select((s) => s.profile?.uid));
  return ref
      .watch(storeRepositoryProvider)
      .get(path, public: path == '/store-settings');
});

class CartLine {
  const CartLine(this.product, this.size, this.quantity);
  final CatalogProduct product;
  final String size;
  final int quantity;
  Json get item => {
    'productId': product.id,
    'size': size,
    'quantity': quantity,
  };
}

final cartProvider = NotifierProvider<CartController, List<CartLine>>(
  CartController.new,
);

class CartController extends Notifier<List<CartLine>> {
  String? _fingerprint, _key;
  @override
  List<CartLine> build() {
    ref.watch(sessionProvider.select((s) => s.profile?.uid));
    _fingerprint = null;
    _key = null;
    return [];
  }

  void add(
    CatalogProduct product,
    String size,
    int available, {
    int units = 1,
  }) {
    final index = state.indexWhere(
      (e) => e.product.id == product.id && e.size == size,
    );
    final quantity = (index < 0 ? 0 : state[index].quantity) + units;
    if (units < 1) throw const AppFailure('Selecciona una cantidad válida.');
    if (quantity > available || quantity > 100) {
      throw const AppFailure(
        'No hay más unidades disponibles para esta talla.',
      );
    }
    if (index < 0 && state.length >= 30) {
      throw const AppFailure('Máximo 30 productos y tallas por pedido.');
    }
    state = index < 0
        ? [...state, CartLine(product, size, quantity)]
        : [
            for (var i = 0; i < state.length; i++)
              if (i == index) CartLine(product, size, quantity) else state[i],
          ];
  }

  void quantity(int index, int value) {
    if (value > 100) return;
    state = [
      for (var i = 0; i < state.length; i++)
        if (i != index)
          state[i]
        else if (value > 0)
          CartLine(state[i].product, state[i].size, value),
    ];
  }

  String checkoutKey(Json payload) {
    final fingerprint = jsonEncode(payload);
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _key = const Uuid().v4();
    }
    return _key!;
  }

  void clear() {
    state = [];
    _key = null;
    _fingerprint = null;
  }
}
