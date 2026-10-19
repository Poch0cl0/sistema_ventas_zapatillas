import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sneakerstore/core/config/app_config.dart';
import 'package:sneakerstore/core/network/api_client.dart';

import 'support/fake_auth_gateway.dart';

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, int) respond;
  int count = 0;
  final headers = <String?>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    headers.add(options.headers['Authorization'] as String?);
    return respond(options, ++count);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody body(int status) => ResponseBody.fromString(
  '{}',
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late FakeAuthGateway auth;
  late Dio api;
  final expired = <String>[];
  setUp(() {
    auth = FakeAuthGateway(currentUid: 'user-1');
    expired.clear();
    api = createApiClient(
      baseUrl: 'http://127.0.0.1:3000',
      auth: auth,
      onSessionExpired: expired.add,
    );
  });
  tearDown(() async {
    api.close();
    await auth.dispose();
  });

  test('Adjunta ID token y renueva una sola vez ante 401', () async {
    final adapter = TestAdapter(
      (_, count) async => body(count == 1 ? 401 : 200),
    );
    api.httpClientAdapter = adapter;
    await api.get<dynamic>('/auth/me');
    expect(adapter.headers, [
      'Bearer test-cached-token',
      'Bearer test-fresh-token',
    ]);
    expect(auth.calls.where((c) => c == 'refreshToken').length, 1);
    expect(expired, isEmpty);
  });
  test('Un segundo 401 cierra la sesión sin un bucle de reintentos', () async {
    final adapter = TestAdapter((_, _) async => body(401));
    api.httpClientAdapter = adapter;
    await expectLater(
      api.get<dynamic>('/auth/me'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.count, 2);
    expect(expired, ['user-1']);
  });
  test('El catálogo público no recibe tokens ni provoca logout', () async {
    final adapter = TestAdapter((_, _) async => body(401));
    api.httpClientAdapter = adapter;
    await expectLater(
      api.get<dynamic>(
        '/products',
        options: Options(extra: {'authenticated': false}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.headers, [null]);
    expect(auth.calls, isEmpty);
    expect(expired, isEmpty);
  });
  test(
    'Un fallo de red durante el reintento no cierra una sesión válida',
    () async {
      api.httpClientAdapter = TestAdapter((options, count) async {
        if (count == 1) return body(401);
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      await expectLater(
        api.get<dynamic>('/auth/me'),
        throwsA(isA<DioException>()),
      );
      expect(expired, isEmpty);
    },
  );
  test(
    'Una respuesta de la cuenta anterior no cierra la cuenta nueva',
    () async {
      api.httpClientAdapter = TestAdapter((_, _) async {
        auth.currentUid = 'user-2';
        return body(401);
      });
      await expectLater(
        api.get<dynamic>('/auth/me'),
        throwsA(isA<DioException>()),
      );
      expect(expired, isEmpty);
      expect(auth.calls, isNot(contains('refreshToken')));
    },
  );
  test('La distribución exige HTTPS y no admite credenciales en la URL', () {
    expect(
      () => AppConfig.validateBaseUrl('http://example.com', allowHttp: false),
      throwsFormatException,
    );
    expect(
      () => AppConfig.validateBaseUrl('https://user:pass@example.com'),
      throwsFormatException,
    );
    expect(
      AppConfig.validateBaseUrl('https://example.com/', allowHttp: false),
      'https://example.com',
    );
  });
}
