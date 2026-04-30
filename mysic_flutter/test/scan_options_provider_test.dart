import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/settings/data/scan_options_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScanOptionsProvider', () {
    test('default values are correct', () {
      final provider = ScanOptionsProvider();

      expect(provider.audioFormats, containsAll(['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape']));
      expect(provider.minFileSizeKb, 100);
      expect(provider.autoDedupe, true);
    });

    test('toggleFormat removes format if present', () async {
      final provider = ScanOptionsProvider();

      await provider.toggleFormat('mp3');
      expect(provider.audioFormats, isNot(contains('mp3')));

      await provider.toggleFormat('mp3');
      expect(provider.audioFormats, contains('mp3'));
    });

    test('setMinFileSizeKb updates value', () async {
      final provider = ScanOptionsProvider();

      await provider.setMinFileSizeKb(500);
      expect(provider.minFileSizeKb, 500);
    });

    test('setAutoDedupe updates value', () async {
      final provider = ScanOptionsProvider();

      await provider.setAutoDedupe(false);
      expect(provider.autoDedupe, false);
    });
  });
}