import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../strings.dart';
import '../theme.dart';

/// Shows exactly what will be burned into the next photo, so nobody has to
/// take a shot to find out whether the fix was good.
class GpsReadout extends StatelessWidget {
  const GpsReadout({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S(SettingsService.instance.language);
    return AnimatedBuilder(
      animation: LocationService.instance,
      builder: (context, _) {
        final loc = LocationService.instance;
        final pos = loc.position;
        final weak = pos != null && pos.accuracy > 25;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: pos == null
                    ? Colors.orangeAccent
                    : weak
                        ? Colors.amber
                        : kArulRed,
                width: 4,
              ),
              top: const BorderSide(color: Colors.white10),
              right: const BorderSide(color: Colors.white10),
              bottom: const BorderSide(color: Colors.white10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pos == null)
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loc.state == GpsState.denied
                          ? s.t('gps_denied')
                          : loc.state == GpsState.serviceOff
                              ? s.t('gps_off')
                              : s.t('waiting_gps'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              else ...[
                Text(
                  LocationService.decimal(pos.latitude, pos.longitude),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocationService.dms(pos.latitude, pos.longitude),
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                if (SettingsService.instance.showAddress) ...[
                  const SizedBox(height: 6),
                  Text(
                    loc.address ?? s.t('no_address'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(
                      Icons.my_location,
                      '\u00B1${pos.accuracy.toStringAsFixed(0)} m',
                      weak ? Colors.amber : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      Icons.terrain_outlined,
                      '${pos.altitude.toStringAsFixed(0)} m',
                      Colors.white70,
                    ),
                    if (loc.heading != null) ...[
                      const SizedBox(width: 8),
                      _chip(
                        Icons.explore_outlined,
                        '${LocationService.compassPoint(loc.heading!)} ${loc.heading!.toStringAsFixed(0)}\u00B0',
                        Colors.white70,
                      ),
                    ],
                  ],
                ),
                if (weak) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.t('weak_gps'),
                    style: const TextStyle(fontSize: 11.5, color: Colors.amber),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, color: color)),
        ],
      ),
    );
  }
}
