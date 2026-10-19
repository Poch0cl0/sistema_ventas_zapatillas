import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String errorMessage(Object error) {
  if (error is AppFailure) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Ingresa un correo electrónico válido.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Correo o contraseña incorrectos.',
      'email-already-in-use' => 'Este correo ya tiene una cuenta. Inicia sesión o recupera tu contraseña.',
      'weak-password' => 'La contraseña no cumple los requisitos de seguridad.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      'too-many-requests' =>
        'Demasiados intentos. Espera un momento y vuelve a intentarlo.',
      'network-request-failed' =>
        'No hay conexión con Firebase. Revisa tu conexión a internet.',
      'operation-not-allowed' =>
        'El acceso con correo y contraseña no está habilitado.',
      _ => 'No pudimos completar la solicitud. Inténtalo nuevamente.',
    };
  }
  if (error is DioException) {
    if (error.error is AppFailure) return (error.error as AppFailure).message;
    if ([400, 409, 413, 429, 502, 503].contains(error.response?.statusCode)) {
      final data = error.response?.data;
      final message = data is Map ? data['message'] : null;
      if (message is String && message.isNotEmpty) return message;
      if (message is List) return message.whereType<String>().join('\n');
    }
    if ([
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ].contains(error.type)) {
      return 'No pudimos conectar con la tienda. Revisa tu conexión e inténtalo nuevamente.';
    }
    return switch (error.response?.statusCode) {
      401 => 'Tu sesión venció. Inicia sesión nuevamente.',
      403 => 'Tu cuenta no tiene permiso para acceder a esta sección.',
      404 => 'El recurso solicitado ya no está disponible.',
      429 => 'Demasiadas solicitudes. Espera un momento.',
      _ =>
        'La tienda no está disponible en este momento. Inténtalo nuevamente.',
    };
  }
  return 'Ocurrió un problema. Inténtalo nuevamente.';
}
