import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/photo_store.dart';
import '../services/settings_service.dart';
import '../strings.dart';
import '../theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<SavedPhoto> _photos = [];
  bool _loading = true;

  S get s => S(SettingsService.instance.language);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await PhotoStore.list();
    if (!mounted) return;
    setState(() {
      _photos = list;
      _loading = false;
    });
  }

  Map<String, List<SavedPhoto>> get _grouped {
    final map = <String, List<SavedPhoto>>{};
    for (final p in _photos) {
      final key = DateFormat('EEEE, d MMMM yyyy').format(p.taken);
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('photos'))),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kArulRed, strokeWidth: 2),
            )
          : _photos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.t('no_photos'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, height: 1.4),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Row(
                          children: [
                            Container(width: 3, height: 14, color: kArulRed),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.value.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        children: [
                          for (final photo in entry.value)
                            GestureDetector(
                              onTap: () => _open(photo),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(photo.file, fit: BoxFit.cover),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
    );
  }

  Future<void> _open(SavedPhoto photo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(photo: photo, onDeleted: _load),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.onDeleted});

  final SavedPhoto photo;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    final s = S(SettingsService.instance.language);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(DateFormat('d MMM yyyy, HH:mm').format(photo.taken)),
        actions: [
          IconButton(
            tooltip: s.t('share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Share.shareXFiles([XFile(photo.file.path)]),
          ),
          IconButton(
            tooltip: s.t('delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, s),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(File(photo.file.path)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(s.t('delete_q')),
        content: Text(s.t('delete_note')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              s.t('delete'),
              style: const TextStyle(color: kArulRed),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await PhotoStore.delete(photo.file);
    await onDeleted();
    if (context.mounted) Navigator.pop(context);
  }
}
