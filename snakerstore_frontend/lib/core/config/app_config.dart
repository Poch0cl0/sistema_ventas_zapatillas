import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const preview = kDebugMode && bool.fromEnvironment('PREVIEW_MODE');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static String validateBaseUrl(String value, {bool allowHttp = kDebugMode}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException(
        'API_BASE_URL debe ser una dirección HTTP o HTTPS sin credenciales.',
      );
    }
    if (!allowHttp && uri.scheme != 'https') {
      throw const FormatException(
        'La versión de distribución requiere una API HTTPS.',
      );
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
