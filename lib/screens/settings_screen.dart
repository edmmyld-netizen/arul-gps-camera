import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../strings.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final s = S(settings.language);
        return Scaffold(
          appBar: AppBar(title: Text(s.t('settings'))),
          body: ListView(
            children: [
              _header(s.t('language')),
              RadioListTile<String>(
                value: 'en',
                groupValue: settings.language,
                onChanged: (v) => settings.setLanguage(v!),
                activeColor: kArulRed,
                title: Text(s.t('english')),
              ),
              RadioListTile<String>(
                value: 'ta',
                groupValue: settings.language,
                onChanged: (v) => settings.setLanguage(v!),
                activeColor: kArulRed,
                title: Text(s.t('tamil')),
              ),
              _header(s.t('stamp')),
              SwitchListTile(
                value: settings.showMap,
                onChanged: settings.setShowMap,
                activeColor: kArulRed,
                title: Text(s.t('show_map')),
                subtitle: Text(s.t('show_map_sub')),
              ),
              SwitchListTile(
                value: settings.showQr,
                onChanged: settings.setShowQr,
                activeColor: kArulRed,
                title: Text(s.t('show_qr')),
                subtitle: Text(s.t('show_qr_sub')),
              ),
              SwitchListTile(
                value: settings.showCompass,
                onChanged: settings.setShowCompass,
                activeColor: kArulRed,
                title: Text(s.t('show_compass')),
              ),
              SwitchListTile(
                value: settings.showAddress,
                onChanged: (v) {
                  settings.setShowAddress(v);
                  LocationService.instance.addressLookupEnabled = v;
                  if (v) LocationService.instance.refreshAddressNow();
                },
                activeColor: kArulRed,
                title: Text(s.t('show_address')),
                subtitle: Text(s.t('show_address_sub')),
              ),
              SwitchListTile(
                value: settings.use24Hour,
                onChanged: settings.setUse24Hour,
                activeColor: kArulRed,
                title: Text(s.t('time_format')),
              ),
              _header(s.t('camera')),
              SwitchListTile(
                value: settings.showGrid,
                onChanged: settings.setShowGrid,
                activeColor: kArulRed,
                title: Text(s.t('grid')),
              ),
              ListTile(
                title: Text(s.t('photo_quality')),
                subtitle: Text(s.t('photo_quality_sub')),
                trailing: DropdownButton<int>(
                  value: settings.maxWidth,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 1280, child: Text('1280 px')),
                    DropdownMenuItem(value: 1920, child: Text('1920 px')),
                    DropdownMenuItem(value: 2560, child: Text('2560 px')),
                    DropdownMenuItem(value: 4000, child: Text('4000 px')),
                  ],
                  onChanged: (v) => settings.setMaxWidth(v!),
                ),
              ),
              _header(s.t('about')),
              ListTile(
                leading: Image.asset('assets/logo/arul_logo_512.png', height: 30),
                title: Text(s.t('app')),
                subtitle: Text('${s.t('version')} $kAppVersion'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Text(
                  'Map thumbnails \u00A9 OpenStreetMap contributors.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        children: [
          Container(width: 3, height: 13, color: kArulRed),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
