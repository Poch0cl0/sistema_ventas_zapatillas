import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../auth/application/session.dart';
import '../../core/network/app_failure.dart';
import 'delivery_repository.dart';

class DeliveryLocationScreen extends ConsumerStatefulWidget {
  const DeliveryLocationScreen({
    super.key,
    this.initial,
    this.readOnly = false,
    this.selectingOrigin = false,
    this.origin,
    this.zoneId,
    this.orderId,
  });
  final DeliveryLocation? initial;
  final bool readOnly;
  final bool selectingOrigin;
  final DeliveryLocation? origin;
  final String? zoneId, orderId;
  @override
  ConsumerState<DeliveryLocationScreen> createState() =>
      _DeliveryLocationState();
}

class _DeliveryLocationState extends ConsumerState<DeliveryLocationScreen> {
  final controller = MapController();
  late Future<DeliveryMapConfig> setup;
  DeliveryMapConfig? config;
  DeliveryLocation? destination;
  DeliveryRoute? route;
  bool locating = false, calculating = false, ready = false, tileError = false;
  bool openSettings = false;
  String? message;
  int generation = 0;
  LatLng get originPoint =>
      route?.origin ?? widget.origin?.point ?? config!.store;

  @override
  void initState() {
    super.initState();
    destination = widget.initial;
    setup = load();
  }

  Future<DeliveryMapConfig> load() async {
    final value = await ref.read(deliveryRepositoryProvider).config();
    if (mounted) config = value;
    return value;
  }

  @override
  void dispose() {
    generation++;
    controller.dispose();
    super.dispose();
  }

  void select(LatLng point) {
    generation++;
    setState(() {
      destination = DeliveryLocation(lat: point.latitude, lon: point.longitude);
      route = null;
      calculating = false;
      message = null;
    });
  }

  Future<void> locate() async {
    if (locating || calculating || widget.readOnly) return;
    final currentGeneration = ++generation;
    setState(() {
      locating = true;
      message = null;
      openSettings = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const AppFailure(
          'Activa la ubicación del celular o toca el mapa para elegir el destino.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        setState(() => openSettings = true);
        throw const AppFailure(
          'La ubicación está bloqueada en Ajustes. Puedes habilitarla o elegir el destino tocando el mapa.',
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw const AppFailure(
          'No se concedió permiso de ubicación. Toca el mapa para elegir el punto de entrega.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted || generation != currentGeneration) return;
      select(LatLng(position.latitude, position.longitude));
      if (ready) controller.move(destination!.point, 17);
    } on TimeoutException {
      if (mounted && generation == currentGeneration)
        setState(
          () => message = 'El GPS está tardando. Puedes reintentar o elegir el punto tocando el mapa.',
        );
    } catch (e) {
      if (mounted && generation == currentGeneration)
        setState(
          () => message = e is AppFailure ? e.message : 'No pudimos obtener tu ubicación. Puedes elegir el destino tocando el mapa.',
        );
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> calculate() async {
    if (calculating || locating || destination == null) return;
    final selected = destination!;
    final currentGeneration = ++generation;
    setState(() {
      calculating = true;
      message = null;
    });
    try {
      final result = await ref
          .read(deliveryRepositoryProvider)
          .route(selected, zoneId: widget.zoneId, orderId: widget.orderId);
      if (!mounted || generation != currentGeneration) return;
      setState(() => route = result);
      if (ready)
        controller.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([
              originPoint,
              selected.point,
              ...result.points,
            ]),
            padding: const EdgeInsets.all(44),
            maxZoom: 17,
          ),
        );
    } catch (e) {
      if (mounted && generation == currentGeneration)
        setState(() => message = errorMessage(e));
    } finally {
      if (mounted && generation == currentGeneration)
        setState(() => calculating = false);
    }
  }

  void mapReady() {
    ready = true;
    if (widget.readOnly && destination != null) {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([originPoint, destination!.point]),
          padding: const EdgeInsets.all(44),
          maxZoom: 17,
        ),
      );
    } else if (destination == null) {
      unawaited(locate());
    }
  }

  @override
  Widget build(BuildContext context) => KineticScaffold(
    appBar: StoreAppBar(
      back: true,
      admin: ref.watch(sessionProvider).profile?.isAdmin == true,
      title: widget.selectingOrigin
          ? 'Punto de salida de la zona'
          : widget.readOnly
          ? 'Destino del pedido'
          : 'Punto de entrega',
    ),
    body: FutureBuilder<DeliveryMapConfig>(
      future: setup,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return EmptyState(
            'No pudimos abrir el mapa',
            errorMessage(snapshot.error!),
            label: 'Reintentar',
            action: () => setState(() {
              ready = false;
              setup = load();
            }),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final map = snapshot.data!;
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  widget.selectingOrigin
                      ? 'Marca la tienda o almacén desde donde saldrán los pedidos de esta zona.'
                      : widget.readOnly
                      ? 'Punto confirmado por el cliente. Calcula la ruta estimada desde el origen guardado.'
                      : 'Toca el mapa en la entrada donde recibirás el pedido. Puedes acercar el mapa para ajustar el pin.',
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: controller,
                      options: MapOptions(
                        initialCenter: destination?.point ?? originPoint,
                        initialZoom: 15,
                        minZoom: 2,
                        maxZoom: 19,
                        onMapReady: mapReady,
                        onTap: widget.readOnly
                            ? null
                            : (_, point) => select(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: map.tileUrl,
                          userAgentPackageName: 'com.example.sneakerstore',
                          maxNativeZoom: 19,
                          panBuffer: 0,
                          errorTileCallback: (_, _, _) {
                            if (tileError) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !tileError)
                                setState(() => tileError = true);
                            });
                          },
                        ),
                        if (route != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: route!.points,
                                strokeWidth: 5,
                                color: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (!widget.selectingOrigin)
                              Marker(
                                point: originPoint,
                                width: 48,
                                height: 48,
                                child: const Tooltip(
                                  message: 'Punto de salida',
                                  child: Icon(
                                    Icons.store,
                                    color: Color(0xFF2563EB),
                                    size: 36,
                                  ),
                                ),
                              ),
                            if (destination != null)
                              Marker(
                                point: destination!.point,
                                width: 48,
                                height: 48,
                                alignment: Alignment.topCenter,
                                child: Tooltip(
                                  message: widget.selectingOrigin
                                      ? 'Punto de salida'
                                      : 'Punto de entrega',
                                  child: Icon(
                                    Icons.location_pin,
                                    color: Color(0xFFD84315),
                                    size: 46,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          map.attribution,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .43,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced([
                      Text(
                        destination == null
                            ? 'Toca el mapa para seleccionar el punto.'
                            : '${widget.selectingOrigin ? 'Origen' : 'Destino'}: ${destination!.label}',
                      ),
                      if (tileError)
                        const Text(
                          'Algunas partes del mapa no cargaron. Revisa internet; puedes volver a abrir el mapa para reintentar.',
                        ),
                      if (message != null)
                        Text(
                          message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (openSettings)
                        TextButton(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                          },
                          child: const Text('Abrir ajustes de ubicación'),
                        ),
                      if (!widget.readOnly)
                        OutlinedButton.icon(
                          onPressed: locating || calculating ? null : locate,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            locating
                                ? 'Buscando ubicación…'
                                : 'Usar mi ubicación',
                          ),
                        ),
                      if (route != null)
                        Text(
                          '${(route!.distance / 1000).toStringAsFixed(2)} km · ${(route!.duration / 60).ceil()} min estimados',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (!widget.selectingOrigin)
                        OutlinedButton.icon(
                          onPressed:
                              destination == null ||
                                  calculating ||
                                  locating ||
                                  !map.routingEnabled
                              ? null
                              : calculate,
                          icon: const Icon(Icons.route),
                          label: Text(
                            calculating
                                ? 'Calculando ruta…'
                                : 'Calcular ruta desde el punto de salida',
                          ),
                        ),
                      if (!widget.selectingOrigin)
                        const Text(
                          'Ruta aproximada de automóvil. El tiempo no incluye preparación ni garantiza la hora de entrega. La tarifa depende de la zona.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      if (!widget.readOnly)
                        FilledButton(
                          onPressed:
                              destination == null || locating || calculating
                              ? null
                              : () => Navigator.pop(context, destination),
                          child: Text(
                            widget.selectingOrigin
                                ? 'Confirmar punto de salida'
                                : 'Confirmar este punto de entrega',
                          ),
                        ),
                    ], gap: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
