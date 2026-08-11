import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/permission_screen.dart';
import 'services/settings_service.dart';
import 'strings.dart';
import 'theme.dart';

List<CameraDescription> cameras = <CameraDescription>[];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Both orientations are allowed - the card scales to whatever width the
  // captured frame ends up being.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SettingsService.instance.load();
  try {
    cameras = await availableCameras();
  } on CameraException {
    cameras = <CameraDescription>[];
  }
  runApp(const ArulGpsCameraApp());
}

class ArulGpsCameraApp extends StatelessWidget {
  const ArulGpsCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) {
        final s = S(SettingsService.instance.language);
        return MaterialApp(
          title: s.t('app'),
          debugShowCheckedModeBanner: false,
          theme: buildArulTheme(),
          home: const PermissionGate(),
        );
      },
    );
  }
}
