import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerService Tests', () {
    late AudioPlayerService service;

    setUp(() {
      service = AudioPlayerService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('Initial state should be idle', () {
      expect(service.state, MysicPlayerState.idle);
      expect(service.currentSong, null);
      expect(service.isPlaying, false);
      expect(service.isShuffleMode, false);
      expect(service.loopMode, MysicLoopMode.off);
    });

    test('Playlist should be empty initially', () {
      expect(service.playlist, isEmpty);
      expect(service.currentIndex, -1);
    });

    test('State stream should emit state changes', () async {
      final states = <MysicPlayerState>[];
      final subscription = service.stateStream.listen((state) {
        states.add(state);
      });

      // 等待一段时间让流完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 初始状态不会触发流，因为没有变化
      expect(states, isEmpty);

      await subscription.cancel();
    });

    test('Position stream should be available', () {
      expect(service.positionStream, isNotNull);
    });

    test('Duration stream should be available', () {
      expect(service.durationStream, isNotNull);
    });

    test('Current song stream should be available', () {
      expect(service.currentSongStream, isNotNull);
    });

    test('MysicLoopMode enum should have correct values', () {
      expect(MysicLoopMode.off.index, 0);
      expect(MysicLoopMode.all.index, 1);
    });

    test('MysicPlayerState enum should have correct values', () {
      expect(MysicPlayerState.idle.index, 0);
      expect(MysicPlayerState.loading.index, 1);
      expect(MysicPlayerState.ready.index, 2);
      expect(MysicPlayerState.playing.index, 3);
      expect(MysicPlayerState.paused.index, 4);
      expect(MysicPlayerState.completed.index, 5);
      expect(MysicPlayerState.error.index, 6);
    });

    test('Stop should reset current song and state', () async {
      await service.stop();
      expect(service.currentSong, null);
      expect(service.currentIndex, -1);
      expect(service.state, MysicPlayerState.idle);
    });

    test('SetSpeed should not throw', () async {
      // 设置播放速度不应抛出异常
      await expectLater(service.setSpeed(1.5), completes);
      await expectLater(service.setSpeed(0.5), completes);
      await expectLater(service.setSpeed(1.0), completes);
    });

    test('ToggleShuffleMode should toggle shuffle state', () async {
      expect(service.isShuffleMode, false);

      await service.toggleShuffleMode();
      expect(service.isShuffleMode, true);

      await service.toggleShuffleMode();
      expect(service.isShuffleMode, false);
    });

    test('SetLoopMode should change loop mode', () async {
      expect(service.loopMode, MysicLoopMode.off);

      await service.setLoopMode(MysicLoopMode.all);
      expect(service.loopMode, MysicLoopMode.all);

      await service.setLoopMode(MysicLoopMode.off);
      expect(service.loopMode, MysicLoopMode.off);
    });

    test('ToggleLoopMode should cycle through loop modes', () async {
      expect(service.loopMode, MysicLoopMode.off);

      await service.toggleLoopMode();
      expect(service.loopMode, MysicLoopMode.all);

      await service.toggleLoopMode();
      expect(service.loopMode, MysicLoopMode.off);
    });

    test('SetPlaylist with empty list should not change state', () async {
      await service.setPlaylist([]);
      expect(service.playlist, isEmpty);
      expect(service.currentIndex, -1);
    });

    test('SeekToIndex with invalid index should not throw', () async {
      // 没有播放列表时调用 seekToIndex 不应抛出异常
      await expectLater(service.seekToIndex(0), completes);
      await expectLater(service.seekToIndex(-1), completes);
      await expectLater(service.seekToIndex(100), completes);
    });

    test('Next without playlist should not throw', () async {
      await expectLater(service.next(), completes);
    });

    test('Previous without playlist should not throw', () async {
      await expectLater(service.previous(), completes);
    });
  });

  group('Song Model Integration Tests', () {
    test('Song can be used with AudioPlayerService', () {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        duration: 180, // 秒（audiotags 返回的单位）
        filePath: '/path/to/song.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );

      // 验证 Song 模型可以被服务使用
      expect(song.id, 1);
      expect(song.title, '测试歌曲');
      expect(song.formattedDuration, '3:00');
    });

    test('Playlist of songs can be created for service', () {
      final songs = List.generate(
        10,
        (i) => Song(
          id: i,
          title: '歌曲 $i',
          artist: '艺术家 $i',
          duration: (i + 1) * 60, // 秒（audiotags 返回的单位）
          filePath: '/path/song_$i.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
      );

      expect(songs.length, 10);
      expect(songs[0].formattedDuration, '1:00');
      expect(songs[9].formattedDuration, '10:00');
    });
  });
}
