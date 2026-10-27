import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../catalog/bundled_models.dart';

/// A capability-scoped loopback origin: camera requires a secure context.
/// Only packaged resources are served. No Firebase tokens, proxy or disk access.
class TryOnServer {
  TryOnServer._(this._server, this.url);
  final HttpServer _server;
  final Uri url;

  static Future<TryOnServer> start(String modelUrl) async {
    final bundled = bundledModels.values.contains(modelUrl);
    final remote = Uri.tryParse(modelUrl);
    if (!bundled &&
        (remote == null ||
            remote.scheme != 'https' ||
            !remote.hasAuthority ||
            remote.userInfo.isNotEmpty)) {
      throw const FormatException('Modelo no compatible con el probador.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final prefix = '/$token/';
    final url = Uri.parse('http://127.0.0.1:${server.port}${prefix}index.html');
    const files = {
      'index.html': 'text/html; charset=utf-8',
      'try_on.js': 'text/javascript',
      'tracking.mjs': 'text/javascript',
      'vendor/three.module.js': 'text/javascript',
      'vendor/GLTFLoader.js': 'text/javascript',
      'vendor/BufferGeometryUtils.js': 'text/javascript',
      'vendor/vision_bundle.mjs': 'text/javascript',
      'vendor/vision_wasm_internal.js': 'text/javascript',
      'vendor/vision_wasm_internal.wasm': 'application/wasm',
      'vendor/vision_wasm_nosimd_internal.js': 'text/javascript',
      'vendor/vision_wasm_nosimd_internal.wasm': 'application/wasm',
      'vendor/pose_landmarker_lite.task': 'application/octet-stream',
      'models/urban_sand.glb': 'model/gltf-binary',
      'models/sport_night.glb': 'model/gltf-binary',
    };
    server.listen((request) async {
      try {
        final path = request.uri.path;
        final host = request.headers.value(HttpHeaders.hostHeader);
        if (request.method != 'GET' ||
            host != '127.0.0.1:${server.port}' ||
            !path.startsWith(prefix)) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          final file = path.substring(prefix.length);
          request.response.headers.set('Cache-Control', 'no-store');
          request.response.headers.set('X-Content-Type-Options', 'nosniff');
          request.response.headers.set(
            'Permissions-Policy',
            'camera=(self), microphone=()',
          );
          request.response.headers.set(
            'Content-Security-Policy',
            "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; "
                "style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; media-src 'self' blob:; "
                "connect-src 'self' ${bundled ? '' : remote!.origin}; worker-src 'self' blob:; frame-ancestors 'none'",
          );
          if (file == 'config.json') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'modelUrl': bundled
                    ? './models/${modelUrl.split('/').last}'
                    : modelUrl,
              }),
            );
          } else if (files.containsKey(file)) {
            final bytes = await rootBundle.load('assets/try_on/$file');
            request.response.headers.set('Content-Type', files[file]!);
            request.response.add(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        }
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        await request.response.close();
      }
    });
    return TryOnServer._(server, url);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}
