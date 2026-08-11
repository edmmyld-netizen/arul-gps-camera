import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

/// Everything needed to burn the info card into one photo.
class StampInput {
  const StampInput({
    required this.jpegBytes,
    required this.maxWidth,
    required this.title,
    required this.addressLine1,
    required this.addressLine2,
    required this.coordsLine,
    required this.dateLine,
    required this.metaLine,
    required this.mapsUrl,
    required this.showQr,
    required this.showMap,
    required this.showCompass,
    this.tileBytes,
    this.tileFx = 0.5,
    this.tileFy = 0.5,
    this.headingDeg,
  });

  final Uint8List jpegBytes;
  final int maxWidth;
  final String title;
  final String addressLine1;
  final String addressLine2;
  final String coordsLine;
  final String dateLine;
  final String metaLine;
  final String? mapsUrl;
  final bool showQr;
  final bool showMap;
  final bool showCompass;
  final Uint8List? tileBytes;
  final double tileFx;
  final double tileFy;
  final double? headingDeg;
}

/// Layout is written in "design units" against a 720 pt wide card, then
/// multiplied by k, so the card keeps the same proportions on a 1080 px
/// portrait shot and on a 4000 px landscape one.
const double _designW = 720;
const double _pad = 14;
const double _box = 130;
const double _gap = 16;
const double _capH = 17;

const Color _white = Color(0xFFFFFFFF);
const Color _grey = Color(0xFFB0B6BE);
const Color _red = Color(0xFFE1131D);
const Color _panelBg = Color(0xD6101216);

class StampService {
  /// Draws the card onto the photo and returns JPEG bytes.
  ///
  /// The drawing runs on the main isolate because Flutter's text engine is not
  /// available in a plain isolate. Only the JPEG encode, the slow part, goes to
  /// a background isolate.
  static Future<Uint8List> stamp(StampInput input) async {
    final codec = await ui.instantiateImageCodec(input.jpegBytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;

    final scale = src.width > input.maxWidth ? input.maxWidth / src.width : 1.0;
    final w = (src.width * scale).round();
    final h = (src.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );

    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );

    ui.Image? tile;
    if (input.showMap && input.tileBytes != null) {
      try {
        final tc = await ui.instantiateImageCodec(input.tileBytes!);
        tile = (await tc.getNextFrame()).image;
      } catch (_) {
        tile = null;
      }
    }

    _drawCard(canvas, w.toDouble(), h.toDouble(), input, tile);

    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.rawRgba);

    src.dispose();
    tile?.dispose();
    out.dispose();
    picture.dispose();

    if (data == null) return input.jpegBytes;
    return compute(_encodeJpeg, _RawFrame(data.buffer.asUint8List(), w, h));
  }
}

class _RawFrame {
  _RawFrame(this.bytes, this.w, this.h);
  final Uint8List bytes;
  final int w;
  final int h;
}

Uint8List _encodeJpeg(_RawFrame f) {
  final im = img.Image.fromBytes(
    width: f.w,
    height: f.h,
    bytes: f.bytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

// ---------------------------------------------------------------------------

TextPainter _text(
  String value,
  double size,
  FontWeight weight,
  Color color,
  double maxWidth,
) {
  final tp = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.15,
      ),
    ),
    maxLines: 1,
    ellipsis: '\u2026',
    textDirection: TextDirection.ltr,
  );
  tp.layout(maxWidth: maxWidth);
  return tp;
}

void _drawCard(
  Canvas canvas,
  double w,
  double h,
  StampInput input,
  ui.Image? tile,
) {
  final k = w / _designW;
  final pad = _pad * k;
  final box = _box * k;
  final gap = _gap * k;

  final hasMap = input.showMap;
  final hasQr = input.showQr && input.mapsUrl != null;

  // Font size and the vertical space each line takes, in design units.
  const rows = <List<double>>[
    [22, 30], // title
    [17, 23], // address line 1
    [17, 26], // address line 2
    [18, 26], // coordinates
    [17, 23], // date and time
    [17, 20], // altitude / accuracy / bearing
  ];
  final textH = rows.fold<double>(0, (sum, r) => sum + r[1]) * k;
  final sideH = box + (hasQr ? _capH * k : 0);
  final cardH = math.max(textH, sideH) + pad * 2;
  final top = h - cardH;

  canvas.drawRect(Rect.fromLTWH(0, top, w, cardH), Paint()..color = _panelBg);
  canvas.drawRect(Rect.fromLTWH(0, top, w, 4 * k), Paint()..color = _red);

  final boxY = top + pad + (cardH - pad * 2 - sideH) / 2;

  if (hasMap) {
    _drawMap(canvas, Rect.fromLTWH(pad, boxY, box, box), k, input, tile);
  }

  var qrLeft = w - pad;
  if (hasQr) {
    qrLeft = w - pad - box;
    _drawQr(canvas, Rect.fromLTWH(qrLeft, boxY, box, box), k, input.mapsUrl!);
  }

  final textX = hasMap ? pad + box + gap : pad;
  final textW = (hasQr ? qrLeft - gap : w - pad) - textX;
  if (textW <= 0) return;

  final values = <String>[
    input.title,
    input.addressLine1,
    input.addressLine2,
    input.coordsLine,
    input.dateLine,
    input.metaLine,
  ];
  const weights = <FontWeight>[
    FontWeight.w700,
    FontWeight.w400,
    FontWeight.w400,
    FontWeight.w600,
    FontWeight.w500,
    FontWeight.w400,
  ];
  const colors = <Color>[_white, _grey, _grey, _white, _white, _grey];

  var y = top + (cardH - textH) / 2;
  for (var i = 0; i < rows.length; i++) {
    if (values[i].isNotEmpty) {
      _text(values[i], rows[i][0] * k, weights[i], colors[i], textW)
          .paint(canvas, Offset(textX, y));
    }
    y += rows[i][1] * k;
  }
}

void _drawMap(
  Canvas canvas,
  Rect rect,
  double k,
  StampInput input,
  ui.Image? tile,
) {
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(6 * k));
  canvas.save();
  canvas.clipRRect(rrect);

  if (tile != null) {
    // A window around the exact point, so the pin never lands on a tile edge.
    const window = 150.0;
    final cx =
        (input.tileFx * tile.width).clamp(window / 2, tile.width - window / 2);
    final cy = (input.tileFy * tile.height)
        .clamp(window / 2, tile.height - window / 2);
    canvas.drawImageRect(
      tile,
      Rect.fromLTWH(cx - window / 2, cy - window / 2, window, window),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  } else {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF2A2E34));
    final line = Paint()
      ..color = const Color(0xFF3C424A)
      ..strokeWidth = 2 * k;
    for (var i = 1; i < 5; i++) {
      final d = rect.width * i / 5;
      canvas.drawLine(Offset(rect.left + d, rect.top),
          Offset(rect.left + d, rect.bottom), line);
      canvas.drawLine(Offset(rect.left, rect.top + d),
          Offset(rect.right, rect.top + d), line);
    }
  }
  canvas.restore();

  final c = rect.center;
  canvas.drawCircle(c, 10 * k, Paint()..color = _white);
  canvas.drawCircle(c, 6 * k, Paint()..color = _red);

  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..color = _white,
  );

  if (input.showCompass && input.headingDeg != null) {
    _drawCompass(
      canvas,
      Offset(rect.right - 28 * k, rect.bottom - 28 * k),
      22 * k,
      input.headingDeg!,
      k,
    );
  }
}

void _drawCompass(
  Canvas canvas,
  Offset centre,
  double r,
  double heading,
  double k,
) {
  canvas.drawCircle(centre, r, Paint()..color = _panelBg);
  canvas.drawCircle(
    centre,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..color = _white,
  );

  // Screen-up is where the camera points, so north sits at minus the heading.
  final a = -heading * math.pi / 180;
  final tip = Offset(
    centre.dx + (r - 5 * k) * math.sin(a),
    centre.dy - (r - 5 * k) * math.cos(a),
  );
  final tail = Offset(
    centre.dx - (r - 10 * k) * math.sin(a),
    centre.dy + (r - 10 * k) * math.cos(a),
  );
  canvas.drawLine(
    tail,
    tip,
    Paint()
      ..color = _red
      ..strokeWidth = 5 * k
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawCircle(centre, 3 * k, Paint()..color = _white);

  final n = _text('N', 12 * k, FontWeight.w600, _white, 40 * k);
  n.paint(canvas, Offset(tip.dx - n.width / 2, tip.dy - n.height / 2));
}

void _drawQr(Canvas canvas, Rect rect, double k, String data) {
  final code = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final image = QrImage(code);
  final n = code.moduleCount;

  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(4 * k)),
    Paint()..color = _white,
  );

  const quiet = 2;
  final cell = rect.width / (n + quiet * 2);
  final dark = Paint()..color = const Color(0xFF000000);
  for (var row = 0; row < n; row++) {
    for (var col = 0; col < n; col++) {
      if (!image.isDark(row, col)) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + (col + quiet) * cell,
          rect.top + (row + quiet) * cell,
          cell + 0.6,
          cell + 0.6,
        ),
        dark,
      );
    }
  }

  final cap = _text('SCAN FOR MAP', 12 * k, FontWeight.w500, _grey, rect.width);
  cap.paint(
    canvas,
    Offset(rect.left + (rect.width - cap.width) / 2, rect.bottom + 3 * k),
  );
}
