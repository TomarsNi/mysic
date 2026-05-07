import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysic_flutter/features/settings/data/play_mode_preference.dart';

void main() {
  group('PlayModePreference', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns default values when not set', () async {
      final mode = await PlayModePreference.load();

      expect(mode.shuffle, false);
      expect(mode.loopMode, 'off');
    });

    test('save and load shuffle mode', () async {
      await PlayModePreference.save(shuffle: true, loopMode: 'off');
      final mode = await PlayModePreference.load();

      expect(mode.shuffle, true);
      expect(mode.loopMode, 'off');
    });

    test('save and load loop mode', () async {
      await PlayModePreference.save(shuffle: false, loopMode: 'all');
      final mode = await PlayModePreference.load();

      expect(mode.shuffle, false);
      expect(mode.loopMode, 'all');
    });

    test('save and load both modes', () async {
      await PlayModePreference.save(shuffle: true, loopMode: 'all');
      final mode = await PlayModePreference.load();

      expect(mode.shuffle, true);
      expect(mode.loopMode, 'all');
    });

    test('overwrite previous values', () async {
      await PlayModePreference.save(shuffle: true, loopMode: 'all');
      await PlayModePreference.save(shuffle: false, loopMode: 'off');
      final mode = await PlayModePreference.load();

      expect(mode.shuffle, false);
      expect(mode.loopMode, 'off');
    });
  });

  group('lastSongId', () {
    test('loadLastSongId returns null when not set', () async {
      final songId = await PlayModePreference.loadLastSongId();
      expect(songId, isNull);
    });

    test('save and load last song id', () async {
      await PlayModePreference.saveLastSongId(42);
      final songId = await PlayModePreference.loadLastSongId();
      expect(songId, 42);
    });

    test('clearLastSongId removes the value', () async {
      await PlayModePreference.saveLastSongId(42);
      await PlayModePreference.clearLastSongId();
      final songId = await PlayModePreference.loadLastSongId();
      expect(songId, isNull);
    });

    test('overwrite previous song id', () async {
      await PlayModePreference.saveLastSongId(42);
      await PlayModePreference.saveLastSongId(100);
      final songId = await PlayModePreference.loadLastSongId();
      expect(songId, 100);
    });
  });
}
