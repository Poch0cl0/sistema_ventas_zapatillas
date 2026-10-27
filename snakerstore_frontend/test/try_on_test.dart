import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sneakerstore/features/catalog/catalog_repository.dart';
import 'package:sneakerstore/features/try_on/try_on_server.dart';

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> product({
    String? bundled = 'urban_sand',
    bool enabled = true,
  }) => {
    'id': 'demo-urban-sand',
    'name': 'Urban Sand',
    'brand': 'Demo',
    'category': 'Urbano',
    'description': 'Demo',
    'priceCents': 19900,
    'active': true,
    'images': [],
    'bundledModel': bundled,
    'tryOnEnabled': enabled,
  };
  test('included and manually uploaded models can use the probador', () {
    final included = CatalogProduct.fromJson(product());
    expect(included.modelUrl, 'assets/try_on/models/urban_sand.glb');
    expect(included.canTryOn, isTrue);
    final uploaded = CatalogProduct.fromJson({
      ...product(),
      'model3d': {
        'format': 'glb',
        'secure_url': 'https://example.com/shoe.glb',
      },
    });
    expect(uploaded.modelUrl, 'https://example.com/shoe.glb');
    expect(uploaded.canTryOn, isTrue);
    expect(CatalogProduct.fromJson(product(enabled: false)).canTryOn, isFalse);
    expect(
      CatalogProduct.fromJson(product(bundled: 'unknown')).canTryOn,
      isFalse,
    );
  });
  test('loopback serves only capability-scoped packaged resources', () async {
    final server = await TryOnServer.start(
      'assets/try_on/models/urban_sand.glb',
    );
    final client = _LoopbackHttpOverrides().createHttpClient(null);
    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });
    final config = await (await client.getUrl(
      server.url.resolve('config.json'),
    )).close();
    expect(config.statusCode, 200);
    await config.drain<void>();
    final model = await (await client.getUrl(
      server.url.resolve('models/urban_sand.glb'),
    )).close();
    final bytes = await model.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    expect(bytes.take(4), [103, 108, 84, 70]);
    final hidden = await (await client.getUrl(
      server.url.resolve('/index.html'),
    )).close();
    expect(hidden.statusCode, 404);
    await hidden.drain<void>();
    final traversal = await (await client.getUrl(
      server.url.resolve('../pubspec.yaml'),
    )).close();
    expect(traversal.statusCode, 404);
    await traversal.drain<void>();
  });
  test('rejects arbitrary local and insecure model sources', () async {
    await expectLater(
      TryOnServer.start('file:///etc/passwd'),
      throwsFormatException,
    );
    await expectLater(
      TryOnServer.start('http://example.com/shoe.glb'),
      throwsFormatException,
    );
    await expectLater(
      TryOnServer.start('assets/private.glb'),
      throwsFormatException,
    );
  });
}
