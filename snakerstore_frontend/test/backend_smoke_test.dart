import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sneakerstore/core/network/api_client.dart';
import 'package:sneakerstore/features/catalog/catalog_repository.dart';

import 'support/fake_auth_gateway.dart';

// Explicit opt-in: this performs read-only requests against a running local NestJS.
const enabled = bool.fromEnvironment('RUN_BACKEND_SMOKE');
const baseUrl = String.fromEnvironment(
  'BACKEND_SMOKE_URL',
  defaultValue: 'http://127.0.0.1:3000',
);
void main() {
  test(
    'NestJS real responde catálogo, zonas y protege perfiles y administración',
    () async {
      final auth = FakeAuthGateway();
      final api = createApiClient(
        baseUrl: baseUrl,
        auth: auth,
        onSessionExpired: (_) {},
      );
      addTearDown(() async {
        api.close();
        await auth.dispose();
      });
      final page = await CatalogRepository(api).list();
      expect(page.items.every((p) => p.active), isTrue);
      if (page.items.isNotEmpty) {
        final product = await CatalogRepository(api).find(page.items.first.id);
        expect(product.id, page.items.first.id);
      }
      final zones = await api.get<Map<String, dynamic>>(
        '/delivery-zones',
        options: Options(extra: {'authenticated': false}),
      );
      expect(zones.data!['items'], isA<List<dynamic>>());
      for (final path in [
        '/auth/me',
        '/admin/products',
        '/admin/orders',
        '/admin/inventory',
        '/admin/delivery-zones',
      ]) {
        // Public option intentionally omits the token to verify the server's guard.
        await expectLater(
          api.get<dynamic>(
            path,
            options: Options(extra: {'authenticated': false}),
          ),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'HTTP',
              401,
            ),
          ),
        );
      }
      expect(auth.calls, isEmpty);
    },
    skip: !enabled,
  );
}
