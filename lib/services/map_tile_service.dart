import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fetches a single OpenStreetMap raster tile for the stamp thumbnail.
/// No API key needed. Tiles are cached on disk, so a spot visited before
/// still draws its map when the phone is offline.
class MapTileService {
  static const int zoom = 16;
  static const String _userAgent =
      'ArulGPSCamera/1.0 (+https://github.com/edmmyld-netizen/arul-gps-camera)';

  static Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'map_tiles'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static ({int x, int y}) _tileXY(double lat, double lng, int z) {
    final n = math.pow(2, z).toDouble();
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    return (x: x, y: y);
  }

  /// Returns raw PNG bytes of the tile containing [lat],[lng], or null.
  static Future<Uint8List?> tileFor(double lat, double lng) async {
    final t = _tileXY(lat, lng, zoom);
    final dir = await _cacheDir();
    final file = File(p.join(dir.path, '${zoom}_${t.x}_${t.y}.png'));

    if (await file.exists()) {
      try {
        return await file.readAsBytes();
      } catch (_) {}
    }

    try {
      final url =
          Uri.parse('https://tile.openstreetmap.org/$zoom/${t.x}/${t.y}.png');
      final res = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(res.bodyBytes, flush: true);
        return res.bodyBytes;
      }
    } catch (_) {
      // Offline - the stamp falls back to a plain coordinate box.
    }
    return null;
  }

  /// Where inside the 256x256 tile the exact point sits, as 0..1 fractions.
  static ({double fx, double fy}) fractionInTile(double lat, double lng) {
    final n = math.pow(2, zoom).toDouble();
    final xf = (lng + 180.0) / 360.0 * n;
    final latRad = lat * math.pi / 180.0;
    final yf =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;
    return (fx: xf - xf.floor(), fy: yf - yf.floor());
  }
}
