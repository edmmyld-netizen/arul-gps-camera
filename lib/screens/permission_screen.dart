import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../strings.dart';
import '../theme.dart';
import 'camera_screen.dart';

/// Shown before the camera. Explains why the two permissions are needed and
/// asks for them together, instead of a bare system dialog appearing out of
/// nowhere on first launch.
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _asking = false;
  bool _permanentlyDenied = false;

  S get s => S(SettingsService.instance.language);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(initial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system settings page - re-check silently.
    if (state == AppLifecycleState.resumed && mounted) _check();
  }

  Future<void> _check({bool initial = false}) async {
    final camera = await Permission.camera.status;
    final location = await Permission.locationWhenInUse.status;
    if (!mounted) return;

    if (camera.isGranted && location.isGranted) {
      _enter();
      return;
    }
    setState(() {
      _checking = false;
      _permanentlyDenied =
          camera.isPermanentlyDenied || location.isPermanentlyDenied;
    });
  }

  Future<void> _request() async {
    setState(() => _asking = true);
    final result = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();
    if (!mounted) return;

    final ok = result.values.every((st) => st.isGranted);
    if (ok) {
      _enter();
      return;
    }
    setState(() {
      _asking = false;
      _permanentlyDenied =
          result.values.any((st) => st.isPermanentlyDenied);
    });
  }

  void _enter() {
    LocationService.instance.start();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: kInk,
        body: Center(
          child: CircularProgressIndicator(color: kArulRed, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kInk,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/logo/arul_logo_512.png', height: 56),
                  const SizedBox(height: 22),
                  Text(
                    s.t('perm_title'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.t('perm_intro'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Colors.white60,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _row(Icons.camera_alt_outlined, s.t('perm_cam'),
                      s.t('perm_cam_why')),
                  const SizedBox(height: 18),
                  _row(Icons.place_outlined, s.t('perm_loc'),
                      s.t('perm_loc_why')),
                  const SizedBox(height: 30),
                  if (_permanentlyDenied) ...[
                    Text(
                      s.t('perm_blocked'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.amber,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kArulRed,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: openAppSettings,
                        child: Text(s.t('open_settings')),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kArulRed,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _asking ? null : _request,
                        child: _asking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(s.t('perm_allow')),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    s.t('perm_note'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, size: 21, color: kArulRed),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
