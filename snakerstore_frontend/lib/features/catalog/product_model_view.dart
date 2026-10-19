import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/ui.dart';

/// No account tokens or private URLs are passed into the WebView.
class ProductModelView extends StatefulWidget {
  const ProductModelView({
    super.key,
    required this.url,
    required this.name,
    this.poster,
    this.interactive = false,
  });
  final String url, name;
  final String? poster;
  final bool interactive;

  @override
  State<ProductModelView> createState() => _VisibleProductModelState();
}

class _VisibleProductModelState extends State<ProductModelView> {
  final visibilityKey = UniqueKey();
  bool visible = false;

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: visibilityKey,
    onVisibilityChanged: (info) {
      final next = info.visibleFraction > .01;
      if (mounted && next != visible) setState(() => visible = next);
    },
    child: visible
        ? _ActiveProductModelView(
            url: widget.url,
            name: widget.name,
            poster: widget.poster,
            interactive: widget.interactive,
          )
        : const ColoredBox(
            color: Color(0xFFF3F3F4),
            child: Center(child: Icon(Icons.view_in_ar_outlined, color: muted)),
          ),
  );
}

class _ActiveProductModelView extends StatefulWidget {
  const _ActiveProductModelView({
    required this.url,
    required this.name,
    this.poster,
    required this.interactive,
  });
  final String url, name;
  final String? poster;
  final bool interactive;

  @override
  State<_ActiveProductModelView> createState() => _ProductModelViewState();
}

class _ProductModelViewState extends State<_ActiveProductModelView> {
  Timer? timeout;
  bool loaded = false, failed = false;
  int attempt = 0;

  @override
  void initState() {
    super.initState();
    startTimeout();
  }

  void startTimeout() {
    timeout?.cancel();
    timeout = Timer(const Duration(seconds: 60), () {
      if (mounted && !loaded) setState(() => failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant _ActiveProductModelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      loaded = false;
      failed = false;
      attempt++;
      startTimeout();
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  Widget fallback() => Stack(
    fit: StackFit.expand,
    children: [
      if (widget.poster != null)
        Image.network(
          widget.poster!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.view_in_ar_outlined, color: muted),
          ),
        )
      else
        const Center(
          child: Icon(Icons.view_in_ar_outlined, color: muted, size: 36),
        ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          color: Colors.white.withValues(alpha: .94),
          padding: const EdgeInsets.all(6),
          child: widget.interactive
              ? TextButton.icon(
                  onPressed: () => setState(() {
                    failed = false;
                    loaded = false;
                    attempt++;
                    startTimeout();
                  }),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar vista 3D'),
                )
              : const Text(
                  'Vista 3D no disponible',
                  style: TextStyle(fontSize: 9, color: muted),
                ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported || failed) return fallback();
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !widget.interactive,
          child: ModelViewer(
            key: ValueKey('${widget.url}:$attempt'),
            src: widget.url,
            alt: widget.name,
            poster: widget.poster,
            ar: false,
            autoRotate: widget.interactive,
            cameraControls: widget.interactive,
            disablePan: true,
            touchAction: TouchAction.panY,
            interactionPrompt: InteractionPrompt.none,
            loading: Loading.eager,
            reveal: Reveal.auto,
            backgroundColor: const Color(0xFFF3F3F4),
            debugLogging: false,
            javascriptChannels: {
              JavascriptChannel(
                'ProductModelStatus',
                onMessageReceived: (message) {
                  if (!mounted) return;
                  timeout?.cancel();
                  setState(() {
                    loaded = message.message == 'ready';
                    failed = !loaded;
                  });
                },
              ),
            },
            relatedJs: '''
          const productModel = document.querySelector('model-viewer');
          productModel.addEventListener('load', () => ProductModelStatus.postMessage('ready'));
          productModel.addEventListener('error', () => ProductModelStatus.postMessage('error'));
          if (productModel.loaded) ProductModelStatus.postMessage('ready');
        ''',
          ),
        ),
        if (!loaded)
          const IgnorePointer(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        const Positioned(
          top: 8,
          left: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '3D',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
