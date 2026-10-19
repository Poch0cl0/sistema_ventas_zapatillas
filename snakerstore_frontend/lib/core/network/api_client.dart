import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/domain/auth_gateway.dart';
import '../config/app_config.dart';
import 'app_failure.dart';

Dio createApiClient({
  required String baseUrl,
  required AuthGateway auth,
  required void Function(String uid) onSessionExpired,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.validateBaseUrl(baseUrl),
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      followRedirects: false,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Public requests never send an identity token, even with an active session.
        if (options.extra['authenticated'] == false) {
          options.headers.remove('Authorization');
          handler.next(options);
          return;
        }
        try {
          final uid = auth.uid;
          if (options.extra['tokenRetried'] == true &&
              options.extra['sessionUid'] != uid) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: const AppFailure(
                  'La sesión cambió. Reintenta la solicitud.',
                ),
              ),
            );
            return;
          }
          final token = await auth.idToken();
          if (uid == null || token == null || uid != auth.uid) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: const AppFailure('Inicia sesión para continuar.'),
              ),
            );
            return;
          }
          options.extra['sessionUid'] = uid;
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        } catch (_) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: const AppFailure(
                'No pudimos verificar tu sesión. Inicia sesión nuevamente.',
              ),
            ),
          );
        }
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        final uid = options.extra['sessionUid'] as String?;
        if (error.response?.statusCode != 401 ||
            options.extra['authenticated'] == false ||
            uid == null ||
            uid != auth.uid) {
          handler.next(error);
          return;
        }
        if (options.extra['tokenRetried'] == true) {
          onSessionExpired(uid);
          handler.next(error);
          return;
        }
        // Only replay reads automatically. Future writes need their own idempotency strategy.
        if (!['GET', 'HEAD'].contains(options.method)) {
          onSessionExpired(uid);
          handler.next(error);
          return;
        }
        try {
          final token = await auth.idToken(forceRefresh: true);
          if (token == null || auth.uid != uid) {
            throw const AppFailure('Sesión inválida.');
          }
          options.extra['tokenRetried'] = true;
          options.headers['Authorization'] = 'Bearer $token';
          final response = await dio.fetch<dynamic>(options);
          handler.resolve(response);
        } on FirebaseAuthException catch (refreshError) {
          if (refreshError.code == 'network-request-failed') {
            handler.next(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            if (auth.uid == uid) onSessionExpired(uid);
            handler.next(error);
          }
        } on DioException catch (retryError) {
          // A network failure during the retry must not log out a valid session.
          handler.next(retryError);
        } catch (_) {
          if (auth.uid == uid) onSessionExpired(uid);
          handler.next(error);
        }
      },
    ),
  );
  return dio;
}
