import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/network/app_failure.dart';
import '../catalog/catalog_repository.dart';
import 'try_on_server.dart';

class TryOnScreen extends ConsumerWidget {
  const TryOnScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Pruébate las zapatillas')),
    body: ref
        .watch(catalogProductProvider((admin: false, id: id)))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(errorMessage(error))),
          data: (product) => !product.canTryOn
              ? const Center(
                  child: Text(
                    'Este producto todavía no tiene probador disponible.',
                  ),
                )
              : kIsWeb || defaultTargetPlatform != TargetPlatform.android
              ? const Center(
                  child: Text(
                    'El probador con cámara está disponible en la app Android.',
                  ),
                )
              : _TryOnSession(
                  key: ValueKey(product.modelUrl),
                  product: product,
                ),
        ),
  );
}

class _TryOnSession extends StatefulWidget {
  const _TryOnSession({super.key, required this.product});
  final CatalogProduct product;
  @override
  State<_TryOnSession> createState() => _TryOnSessionState();
}

class _TryOnSessionState extends State<_TryOnSession>
    with WidgetsBindingObserver {
  static const permissions = MethodChannel('sneakerstore/camera_permission');
  TryOnServer? server;
  WebViewController? controller;
  String? failure;
  bool suspended = false;
  bool cameraAllowed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    try {
      final local = await TryOnServer.start(widget.product.modelUrl!);
      if (!mounted) {
        await local.close();
        return;
      }
      server = local;
      final web = WebViewController(
        onPermissionRequest: (request) async {
          if (cameraAllowed &&
              request.types.every(
                (t) => t == WebViewPermissionResourceType.camera,
              )) {
            await request.grant();
          } else {
            await request.deny();
          }
        },
      );
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(const Color(0xFF111111));
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == local.url.toString()
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      await web.addJavaScriptChannel(
        'TryOnBridge',
        onMessageReceived: (message) async {
          if (message.message != 'requestCamera' || !mounted) return;
          try {
            cameraAllowed =
                await permissions.invokeMethod<bool>('request') ?? false;
          } catch (_) {
            cameraAllowed = false;
          }
          if (mounted) {
            await web.runJavaScript(
              'window.cameraPermissionResult?.(${cameraAllowed ? 'true' : 'false'})',
            );
          }
        },
      );
      if (web.platform is AndroidWebViewController) {
        await (web.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await web.loadRequest(local.url);
      if (mounted) setState(() => controller = web);
    } catch (_) {
      await server?.close();
      server = null;
      if (mounted) {
        setState(
          () => failure =
              'No se pudo iniciar el probador. Vuelve al producto y reintenta.',
        );
      }
    }
  }

  Future<void> stopCamera() async {
    try {
      await controller?.runJavaScript('window.stopTryOn?.()');
    } catch (_) {
      /* WebView may already be disposed. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(stopCamera());
      if (mounted) setState(() => suspended = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stopCamera());
    unawaited(server?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(failure!),
        ),
      );
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.product.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: controller!),
              if (suspended)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Reanudar probador'),
                        onPressed: () async {
                          await controller!.loadRequest(server!.url);
                          if (mounted) setState(() => suspended = false);
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver al producto y elegir talla'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
