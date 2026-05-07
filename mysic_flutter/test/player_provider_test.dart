import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerProvider Tests', () {
    late PlayerProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = PlayerProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial state should be idle', () {
      expect(provider.playerState, MysicPlayerState.idle);
      expect(provider.currentSong, null);
      expect(provider.isPlaying, false);
      expect(provider.isPaused, false);
      expect(provider.isLoading, false);
    });

    test('Initial playlist should be empty', () {
      expect(provider.playlist, isEmpty);
      expect(provider.currentIndex, -1);
      expect(provider.hasPlaylist, false);
    });

    test('Initial shuffle mode should be off', () {
      expect(provider.isShuffleMode, false);
    });

    test('Initial loop mode should be off', () {
      expect(provider.loopMode, MysicLoopMode.off);
    });

    test('Progress should be 0 when no duration', () {
      expect(provider.progress, 0.0);
    });

    test('Formatted position should return correct format', () {
      expect(provider.formattedPosition, '0:00');
    });

    test('Formatted duration should return placeholder when null', () {
      expect(provider.formattedDuration, '--:--');
    });

    test('hasCurrentSong should be false initially', () {
      expect(provider.hasCurrentSong, false);
    });

    test('ToggleShuffleMode should toggle shuffle state', () async {
      expect(provider.isShuffleMode, false);

      await provider.toggleShuffleMode();
      expect(provider.isShuffleMode, true);

      await provider.toggleShuffleMode();
      expect(provider.isShuffleMode, false);
    });

    test('SetLoopMode should change loop mode', () async {
      expect(provider.loopMode, MysicLoopMode.off);

      await provider.setLoopMode(MysicLoopMode.all);
      expect(provider.loopMode, MysicLoopMode.all);

      await provider.setLoopMode(MysicLoopMode.off);
      expect(provider.loopMode, MysicLoopMode.off);
    });

    test('ToggleLoopMode should cycle through loop modes', () async {
      expect(provider.loopMode, MysicLoopMode.off);

      await provider.toggleLoopMode();
      expect(provider.loopMode, MysicLoopMode.all);

      await provider.toggleLoopMode();
      expect(provider.loopMode, MysicLoopMode.off);
    });

    test('AddToPlaylist should add song to playlist', () {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        filePath: '/path/to/song.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );

      provider.addToPlaylist(song);
      expect(provider.playlist.length, 1);
      expect(provider.playlist[0].id, 1);
      expect(provider.hasPlaylist, true);
    });

    test('RemoveFromPlaylist should remove song from playlist', () {
      final songs = List.generate(
        3,
        (i) => Song(
          id: i,
          title: '歌曲 $i',
          filePath: '/path/song_$i.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
      );

      // 添加歌曲
      for (final song in songs) {
        provider.addToPlaylist(song);
      }
      expect(provider.playlist.length, 3);

      // 移除中间的歌曲
      provider.removeFromPlaylist(1);
      expect(provider.playlist.length, 2);
      expect(provider.playlist[0].id, 0);
      expect(provider.playlist[1].id, 2);
    });

    test('RemoveFromPlaylist with invalid index should not throw', () {
      provider.removeFromPlaylist(-1);
      provider.removeFromPlaylist(0);
      provider.removeFromPlaylist(100);
      expect(provider.playlist, isEmpty);
    });

    test('ClearPlaylist should clear all songs', () async {
      final songs = List.generate(
        3,
        (i) => Song(
          id: i,
          title: '歌曲 $i',
          filePath: '/path/song_$i.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
      );

      for (final song in songs) {
        provider.addToPlaylist(song);
      }
      expect(provider.playlist.length, 3);

      await provider.clearPlaylist();
      expect(provider.playlist, isEmpty);
      expect(provider.currentIndex, -1);
    });

    test('SeekToProgress should not throw when duration is null', () async {
      await provider.seekToProgress(0.5);
      // 不应抛出异常
    });

    test('SeekToIndex with invalid index should not throw', () async {
      await provider.seekToIndex(-1);
      await provider.seekToIndex(0);
      await provider.seekToIndex(100);
      // 不应抛出异常
    });

    test('Stop should reset state', () async {
      await provider.stop();
      expect(provider.currentSong, null);
      expect(provider.currentIndex, -1);
      expect(provider.playerState, MysicPlayerState.idle);
    });

    test('SetSpeed should not throw', () async {
      await provider.setSpeed(1.5);
      await provider.setSpeed(0.5);
      await provider.setSpeed(1.0);
      // 不应抛出异常
    });

    test('Next without playlist should not throw', () async {
      await provider.next();
      // 不应抛出异常
    });

    test('Previous without playlist should not throw', () async {
      await provider.previous();
      // 不应抛出异常
    });
  });

  group('PlayerProvider with Song Tests', () {
    late PlayerProvider provider;

    setUp(() {
      provider = PlayerProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('Song model should work with provider', () {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        album: '测试专辑',
        duration: 180000,
        filePath: '/path/to/song.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );

      provider.addToPlaylist(song);
      expect(provider.playlist.first.title, '测试歌曲');
      expect(provider.playlist.first.displayArtist, '测试艺术家');
    });

    test('Multiple songs should be added to playlist', () {
      final songs = List.generate(
        10,
        (i) => Song(
          id: i,
          title: '歌曲 $i',
          artist: '艺术家 $i',
          duration: (i + 1) * 60000,
          filePath: '/path/song_$i.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
      );

      for (final song in songs) {
        provider.addToPlaylist(song);
      }

      expect(provider.playlist.length, 10);
      expect(provider.playlist[0].formattedDuration, '1:00');
      expect(provider.playlist[9].formattedDuration, '10:00');
    });
  });
}
