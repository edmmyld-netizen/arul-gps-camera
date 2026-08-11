import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SavedPhoto {
  SavedPhoto(this.file, this.taken);
  final File file;
  final DateTime taken;
}

class PhotoStore {
  static const String albumName = 'Arul GPS Camera';

  static Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes the stamped JPEG into the app's own dated folder and copies it to
  /// the phone gallery album. Returns the app-side file.
  static Future<File> save(Uint8List bytes, DateTime taken) async {
    final root = await _root();
    final dayFolder = Directory(
      p.join(root.path, DateFormat('yyyy-MM-dd').format(taken)),
    );
    if (!await dayFolder.exists()) await dayFolder.create(recursive: true);

    final name = 'ARUL_${DateFormat('yyyyMMdd_HHmmss').format(taken)}.jpg';
    final file = File(p.join(dayFolder.path, name));
    await file.writeAsBytes(bytes, flush: true);

    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImage(file.path, album: albumName);
    } catch (_) {
      // Gallery copy failed - the app-side file is still saved.
    }
    return file;
  }

  static Future<List<SavedPhoto>> list() async {
    final root = await _root();
    final out = <SavedPhoto>[];
    await for (final entity in root.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
        out.add(SavedPhoto(entity, (await entity.stat()).modified));
      }
    }
    out.sort((a, b) => b.taken.compareTo(a.taken));
    return out;
  }

  static Future<void> delete(File f) async {
    if (await f.exists()) await f.delete();
  }
}
