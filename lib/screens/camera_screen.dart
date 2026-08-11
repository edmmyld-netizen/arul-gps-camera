import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../services/location_service.dart';
import '../services/map_tile_service.dart';
import '../services/photo_store.dart';
import '../services/settings_service.dart';
import '../services/stamp_service.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/grid_overlay.dart';
import '../widgets/gps_readout.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _cameraIndex = 0;
  FlashMode _flash = FlashMode.off;
  bool _busy = false;
  bool _cameraDenied = false;
  File? _lastPhoto;

  S get s => S(SettingsService.instance.language);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
    _loadLastPhoto();
  }

  Future<void> _loadLastPhoto() async {
    final all = await PhotoStore.list();
    if (!mounted || all.isEmpty) return;
    setState(() => _lastPhoto = all.first.file);
  }

  Future<void> _setupCamera() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      if (mounted) setState(() => _cameraDenied = true);
      return;
    }
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (_) {}
    }
    if (cameras.isEmpty) return;

    final controller = CameraController(
      cameras[_cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash);
    } on CameraException {
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraDenied = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
      LocationService.instance.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) return;
    await _controller?.dispose();
    setState(() {
      _controller = null;
      _cameraIndex = (_cameraIndex + 1) % cameras.length;
    });
    await _setupCamera();
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException {
      // Front cameras often have no flash unit.
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();

    try {
      final shot = await c.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      final taken = DateTime.now();

      final loc = LocationService.instance;
      final settings = SettingsService.instance;
      final pos = loc.position;

      Uint8List? tile;
      double fx = 0.5, fy = 0.5;
      if (settings.showMap && pos != null) {
        tile = await MapTileService.tileFor(pos.latitude, pos.longitude);
        final f = MapTileService.fractionInTile(pos.latitude, pos.longitude);
        fx = f.fx;
        fy = f.fy;
      }

      final stamped = await StampService.stamp(
        _buildInput(bytes, taken, pos, tile, fx, fy),
      );
      final file = await PhotoStore.save(stamped, taken);

      try {
        await File(shot.path).delete();
      } catch (_) {}

      if (!mounted) return;
      setState(() => _lastPhoto = file);
      _toast(s.t('saved'));
    } catch (_) {
      if (mounted) _toast(s.t('save_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The card is always written in English so it reads the same to whoever
  /// receives the photo, no matter which UI language is set.
  StampInput _buildInput(
    Uint8List bytes,
    DateTime taken,
    Position? pos,
    Uint8List? tile,
    double fx,
    double fy,
  ) {
    final loc = LocationService.instance;
    final settings = SettingsService.instance;

    final timePart = settings.use24Hour ? 'HH:mm:ss' : 'hh:mm:ss a';
    final dateLine =
        '${DateFormat('EEEE, d MMMM yyyy').format(taken)}  '
        '${DateFormat(timePart).format(taken)} ${taken.timeZoneName}';

    final meta = <String>[];
    if (pos != null) {
      meta.add('Alt ${pos.altitude.toStringAsFixed(0)} m');
      meta.add('Acc \u00B1${pos.accuracy.toStringAsFixed(0)} m');
    }
    if (loc.heading != null) {
      meta.add(
        'Bearing ${LocationService.compassPoint(loc.heading!)} '
        '${loc.heading!.toStringAsFixed(0)}\u00B0',
      );
    }

    final hasAddress = settings.showAddress && (loc.placeTitle ?? '').isNotEmpty;

    return StampInput(
      jpegBytes: bytes,
      maxWidth: settings.maxWidth,
      title: hasAddress ? loc.placeTitle! : '',
      addressLine1: !settings.showAddress
          ? ''
          : (loc.addressLine1 ?? 'Address unavailable offline'),
      addressLine2: settings.showAddress ? (loc.addressLine2 ?? '') : '',
      coordsLine: pos == null
          ? 'Location unavailable'
          : LocationService.latLongLabel(pos.latitude, pos.longitude),
      dateLine: dateLine,
      metaLine: meta.join('   \u00B7   '),
      mapsUrl: pos == null
          ? null
          : 'https://maps.google.com/?q=${pos.latitude.toStringAsFixed(6)},'
              '${pos.longitude.toStringAsFixed(6)}',
      showQr: settings.showQr,
      showMap: settings.showMap,
      showCompass: settings.showCompass,
      tileBytes: tile,
      tileFx: fx,
      tileFy: fy,
      headingDeg: loc.heading,
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) {
        final landscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        return Scaffold(
          backgroundColor: kInk,
          body: SafeArea(child: landscape ? _landscape() : _portrait()),
        );
      },
    );
  }

  Widget _portrait() {
    return Column(
      children: [
        _topBar(),
        Expanded(child: _preview()),
        const GpsReadout(),
        _controls(vertical: false),
      ],
    );
  }

  Widget _landscape() {
    return Row(
      children: [
        Expanded(child: _preview()),
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: const SingleChildScrollView(child: GpsReadout()),
              ),
              _controls(vertical: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Image.asset('assets/logo/arul_logo_512.png', height: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.t('app'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              LocationService.instance.addressLookupEnabled =
                  SettingsService.instance.showAddress;
            },
            icon: const Icon(Icons.tune),
            tooltip: s.t('settings'),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_cameraDenied) {
      return _message(
        Icons.no_photography_outlined,
        s.t('cam_denied'),
        s.t('grant_cam_loc'),
        s.t('open_settings'),
        openAppSettings,
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: kArulRed, strokeWidth: 2),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / c.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(c),
            if (SettingsService.instance.showGrid) const GridOverlay(),
            if (_busy)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: kArulRed,
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 14),
                      Text(s.t('stamping')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String body,
    String action,
    VoidCallback onAction,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white38),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kArulRed),
              onPressed: onAction,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls({required bool vertical}) {
    final shutter = GestureDetector(
      onTap: _busy ? null : _capture,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 3),
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: kArulRed,
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ),
      ),
    );

    final side = [
      IconButton(
        onPressed: _cycleFlash,
        icon: Icon(
          _flash == FlashMode.off
              ? Icons.flash_off
              : _flash == FlashMode.auto
                  ? Icons.flash_auto
                  : Icons.flash_on,
        ),
      ),
      IconButton(
        onPressed: _switchCamera,
        icon: const Icon(Icons.cameraswitch_outlined),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_thumbButton(), ...side],
                ),
                const SizedBox(height: 12),
                shutter,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _thumbButton(),
                shutter,
                Column(mainAxisSize: MainAxisSize.min, children: side),
              ],
            ),
    );
  }

  Widget _thumbButton() {
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GalleryScreen()),
        );
        _loadLastPhoto();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
          image: _lastPhoto == null
              ? null
              : DecorationImage(
                  image: FileImage(_lastPhoto!),
                  fit: BoxFit.cover,
                ),
        ),
        child: _lastPhoto == null
            ? const Icon(Icons.photo_library_outlined, size: 22)
            : null,
      ),
    );
  }
}
