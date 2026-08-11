import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum GpsState { idle, denied, serviceOff, searching, ready }

class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _posSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _addressTimer;

  // Low-pass filtered sensor vectors, used for the tilt-compensated compass.
  List<double>? _gravity;
  List<double>? _geomagnetic;
  DateTime _lastHeadingPush = DateTime.fromMillisecondsSinceEpoch(0);

  GpsState state = GpsState.idle;
  Position? position;
  double? heading;
  String? address;
  String? placeTitle;
  String? addressLine1;
  String? addressLine2;
  bool addressLookupEnabled = true;

  double? _lastGeocodedLat;
  double? _lastGeocodedLng;

  Future<void> start() async {
    state = GpsState.searching;
    notifyListeners();

    if (!await Geolocator.isLocationServiceEnabled()) {
      state = GpsState.serviceOff;
      notifyListeners();
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      state = GpsState.denied;
      notifyListeners();
      return;
    }

    await _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((p) {
      position = p;
      state = GpsState.ready;
      notifyListeners();
      _maybeGeocode(p);
    });

    await _accelSub?.cancel();
    await _magSub?.cancel();
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((e) {
      _gravity = _lowPass(_gravity, [e.x, e.y, e.z]);
      _updateHeading();
    });
    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((e) {
      _geomagnetic = _lowPass(_geomagnetic, [e.x, e.y, e.z]);
      _updateHeading();
    });
  }

  /// Smooths raw sensor noise. Without this the needle jitters constantly.
  List<double> _lowPass(List<double>? prev, List<double> next) {
    if (prev == null) return next;
    const alpha = 0.2;
    return [
      prev[0] + alpha * (next[0] - prev[0]),
      prev[1] + alpha * (next[1] - prev[1]),
      prev[2] + alpha * (next[2] - prev[2]),
    ];
  }

  /// Same maths Android's SensorManager uses: build a rotation matrix from
  /// gravity and the magnetic field, then read the azimuth out of it. Works
  /// when the phone is tilted, which a plain magnetometer reading does not.
  void _updateHeading() {
    final g = _gravity;
    final m = _geomagnetic;
    if (g == null || m == null) return;

    // H = m x g, then normalise.
    var hx = m[1] * g[2] - m[2] * g[1];
    var hy = m[2] * g[0] - m[0] * g[2];
    var hz = m[0] * g[1] - m[1] * g[0];
    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return; // too close to a magnet or free fall
    hx /= normH;
    hy /= normH;
    hz /= normH;

    final normG = math.sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
    if (normG == 0) return;
    final ax = g[0] / normG;
    final ay = g[1] / normG;
    final az = g[2] / normG;

    // M = A x H
    final mx = ay * hz - az * hy;
    final my = az * hx - ax * hz;

    final azimuth = math.atan2(hy, my) * 180 / math.pi;
    final next = (azimuth + 360) % 360;

    // Push at most 10 times a second so the UI is not rebuilt on every sample.
    final now = DateTime.now();
    if (now.difference(_lastHeadingPush).inMilliseconds < 100) {
      heading = next;
      return;
    }
    _lastHeadingPush = now;
    heading = next;
    notifyListeners();
  }

  /// Reverse geocoding is throttled: only when the fix moves ~25 m or after 20 s.
  void _maybeGeocode(Position p) {
    if (!addressLookupEnabled) return;
    final moved = _lastGeocodedLat == null ||
        Geolocator.distanceBetween(
              _lastGeocodedLat!,
              _lastGeocodedLng!,
              p.latitude,
              p.longitude,
            ) >
            25;
    if (!moved && address != null) return;
    if (_addressTimer?.isActive ?? false) return;

    _addressTimer = Timer(const Duration(seconds: 20), () {});
    _lastGeocodedLat = p.latitude;
    _lastGeocodedLng = p.longitude;
    _lookupAddress(p.latitude, p.longitude);
  }

  Future<void> _lookupAddress(double lat, double lng) async {
    try {
      await setLocaleIdentifier('en_IN');
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return;
      final m = marks.first;
      final parts = <String>[
        if ((m.name ?? '').isNotEmpty && m.name != m.subLocality) m.name!,
        if ((m.subLocality ?? '').isNotEmpty) m.subLocality!,
        if ((m.locality ?? '').isNotEmpty) m.locality!,
        if ((m.subAdministrativeArea ?? '').isNotEmpty) m.subAdministrativeArea!,
        if ((m.administrativeArea ?? '').isNotEmpty) m.administrativeArea!,
        if ((m.postalCode ?? '').isNotEmpty) m.postalCode!,
      ];
      final seen = <String>{};
      address = parts.where(seen.add).join(', ');

      // The stamp card wants a bold place name and two calmer detail lines,
      // the way a maps app lays out a location.
      final town = _first([m.subLocality, m.locality, m.name]);
      final district = _first([m.subAdministrativeArea, m.locality]);
      placeTitle = <String>{
        if (town != null) town,
        if (district != null && district != town) district,
      }.join(', ');
      if (placeTitle!.isEmpty) placeTitle = m.name ?? '';

      final detail = <String>{
        if ((m.name ?? '').isNotEmpty) m.name!,
        if ((m.street ?? '').isNotEmpty) m.street!,
        if ((m.subLocality ?? '').isNotEmpty) m.subLocality!,
      };
      addressLine1 = detail.join(', ');

      final tail = <String>[
        if ((m.administrativeArea ?? '').isNotEmpty)
          '${m.administrativeArea}${(m.postalCode ?? '').isNotEmpty ? ' ${m.postalCode}' : ''}',
        if ((m.country ?? '').isNotEmpty) m.country!,
      ];
      addressLine2 = tail.join(', ');

      notifyListeners();
    } catch (_) {
      // Offline or geocoder unavailable - coordinates still stamp fine.
    }
  }

  Future<void> refreshAddressNow() async {
    final p = position;
    if (p == null) return;
    await _lookupAddress(p.latitude, p.longitude);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _addressTimer?.cancel();
    super.dispose();
  }

  static String? _first(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  // ---- formatting helpers -------------------------------------------------

  static String decimal(double lat, double lng) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(6)}\u00B0$ns  ${lng.abs().toStringAsFixed(6)}\u00B0$ew';
  }

  /// The label used on the stamp card, in the style a maps app shows it.
  static String latLongLabel(double lat, double lng) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return 'Lat ${lat.abs().toStringAsFixed(6)}\u00B0 $ns   '
        'Long ${lng.abs().toStringAsFixed(6)}\u00B0 $ew';
  }

  static String dms(double lat, double lng) {
    return '${_dmsPart(lat, 'N', 'S')}  ${_dmsPart(lng, 'E', 'W')}';
  }

  static String _dmsPart(double v, String pos, String neg) {
    final hemi = v >= 0 ? pos : neg;
    final a = v.abs();
    final d = a.floor();
    final mFull = (a - d) * 60;
    final m = mFull.floor();
    final s = (mFull - m) * 60;
    return '$d\u00B0 $m\' ${s.toStringAsFixed(1)}" $hemi';
  }

  static String compassPoint(double heading) {
    const points = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final i = ((heading % 360) / 22.5).round() % 16;
    return points[i];
  }
}
