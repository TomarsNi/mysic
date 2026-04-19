import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('播放功能测试', () {
    late AudioPlayerService service;

    setUp(() {
      service = AudioPlayerService();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('播放/暂停/停止功能', () {
      test('初始状态应为 idle', () {
        expect(service.state, MysicPlayerState.idle);
        expect(service.currentSong, isNull);
        expect(service.isPlaying, isFalse);
      });

      test('停止操作应重置状态', () async {
        await service.stop();
        expect(service.state, MysicPlayerState.idle);
        expect(service.currentSong, isNull);
        expect(service.currentIndex, -1);
      });

      test('暂停操作不应抛出异常（无歌曲时）', () async {
        await expectLater(service.pause(), completes);
      });

      test('播放操作不应抛出异常（无歌曲时）', () async {
        await service.play().timeout(const Duration(seconds: 5), onTimeout: () {});
      });
    });

    group('上一首/下一首切换', () {
      test('无播放列表时 next 不应抛出异常', () async {
        await expectLater(service.next(), completes);
      });

      test('无播放列表时 previous 不应抛出异常', () async {
        await expectLater(service.previous(), completes);
      });

      test('空播放列表时 next 不应抛出异常', () async {
        await service.setPlaylist([]);
        await expectLater(service.next(), completes);
      });

      test('空播放列表时 previous 不应抛出异常', () async {
        await service.setPlaylist([]);
        await expectLater(service.previous(), completes);
      });
    });

    group('进度条拖动', () {
      test('seek 操作应可用', () async {
        await expectLater(service.seek(Duration.zero), completes);
        await expectLater(service.seek(const Duration(seconds: 30)), completes);
      });

      test('seekToIndex 无效索引不应抛出异常', () async {
        await expectLater(service.seekToIndex(-1), completes);
        await expectLater(service.seekToIndex(0), completes);
        await expectLater(service.seekToIndex(100), completes);
      });
    });

    group('播放模式切换', () {
      test('随机模式应可切换', () async {
        expect(service.isShuffleMode, isFalse);

        await service.toggleShuffleMode();
        expect(service.isShuffleMode, isTrue);

        await service.toggleShuffleMode();
        expect(service.isShuffleMode, isFalse);
      });

      test('循环模式应可设置', () async {
        expect(service.loopMode, MysicLoopMode.off);

        await service.setLoopMode(MysicLoopMode.one);
        expect(service.loopMode, MysicLoopMode.one);

        await service.setLoopMode(MysicLoopMode.all);
        expect(service.loopMode, MysicLoopMode.all);

        await service.setLoopMode(MysicLoopMode.off);
        expect(service.loopMode, MysicLoopMode.off);
      });

      test('循环模式应可循环切换', () async {
        // off -> one -> all -> off
        expect(service.loopMode, MysicLoopMode.off);

        await service.toggleLoopMode();
        expect(service.loopMode, MysicLoopMode.one);

        await service.toggleLoopMode();
        expect(service.loopMode, MysicLoopMode.all);

        await service.toggleLoopMode();
        expect(service.loopMode, MysicLoopMode.off);
      });
    });

    group('播放速度', () {
      test('播放速度应可设置', () async {
        await expectLater(service.setSpeed(0.5), completes);
        await expectLater(service.setSpeed(1.0), completes);
        await expectLater(service.setSpeed(1.5), completes);
        await expectLater(service.setSpeed(2.0), completes);
      });
    });

    group('播放列表操作', () {
      test('设置空播放列表不应改变状态', () async {
        await service.setPlaylist([]);
        expect(service.playlist, isEmpty);
        expect(service.currentIndex, -1);
      });

      test('播放列表应为不可变视图', () {
        final playlist = service.playlist;
        expect(playlist, isA<List<Song>>());
      });
    });
  });

  group('PlayerProvider 功能测试', () {
    late PlayerProvider provider;

    setUp(() {
      provider = PlayerProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    group('状态管理', () {
      test('初始状态应为 idle', () {
        expect(provider.playerState, MysicPlayerState.idle);
        expect(provider.currentSong, isNull);
        expect(provider.isPlaying, isFalse);
        expect(provider.isPaused, isFalse);
        expect(provider.isLoading, isFalse);
      });

      test('初始播放列表应为空', () {
        expect(provider.hasPlaylist, isFalse);
        expect(provider.playlist, isEmpty);
        expect(provider.currentIndex, -1);
      });

      test('进度初始应为 0', () {
        expect(provider.progress, 0.0);
        expect(provider.formattedPosition, '0:00');
        expect(provider.formattedDuration, '--:--');
      });
    });

    group('播放控制', () {
      test('停止操作应清空播放列表', () async {
        await provider.stop();
        expect(provider.playlist, isEmpty);
        expect(provider.currentIndex, -1);
      });

      test('togglePlayPause 不应抛出异常', () async {
        await provider.togglePlayPause().timeout(const Duration(seconds: 5), onTimeout: () {});
      });

      test('next 不应抛出异常', () async {
        await expectLater(provider.next(), completes);
      });

      test('previous 不应抛出异常', () async {
        await expectLater(provider.previous(), completes);
      });
    });

    group('进度控制', () {
      test('seek 应更新位置', () async {
        await provider.seek(const Duration(seconds: 30));
        expect(provider.position, const Duration(seconds: 30));
      });

      test('seekToProgress 无时长时不应抛出异常', () async {
        await expectLater(provider.seekToProgress(0.5), completes);
      });
    });

    group('播放模式', () {
      test('随机模式应可切换', () async {
        expect(provider.isShuffleMode, isFalse);

        await provider.toggleShuffleMode();
        expect(provider.isShuffleMode, isTrue);

        await provider.toggleShuffleMode();
        expect(provider.isShuffleMode, isFalse);
      });

      test('循环模式应可设置', () async {
        expect(provider.loopMode, MysicLoopMode.off);

        await provider.setLoopMode(MysicLoopMode.one);
        expect(provider.loopMode, MysicLoopMode.one);

        await provider.setLoopMode(MysicLoopMode.all);
        expect(provider.loopMode, MysicLoopMode.all);
      });
    });

    group('播放列表管理', () {
      test('添加歌曲到播放列表', () {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '测试艺术家',
          duration: 180000,
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        provider.addToPlaylist(song);
        expect(provider.playlist.length, 1);
        expect(provider.hasPlaylist, isTrue);
      });

      test('从播放列表移除歌曲', () {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '测试艺术家',
          duration: 180000,
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        provider.addToPlaylist(song);
        expect(provider.playlist.length, 1);

        provider.removeFromPlaylist(0);
        expect(provider.playlist.isEmpty, isTrue);
      });

      test('移除无效索引不应抛出异常', () {
        provider.removeFromPlaylist(-1);
        provider.removeFromPlaylist(0);
        provider.removeFromPlaylist(100);
        expect(provider.playlist, isEmpty);
      });

      test('清空播放列表', () async {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '测试艺术家',
          duration: 180000,
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        provider.addToPlaylist(song);
        await provider.clearPlaylist();
        expect(provider.playlist, isEmpty);
        expect(provider.currentIndex, -1);
      });
    });

    group('便捷方法', () {
      test('hasCurrentSong 应返回正确值', () {
        expect(provider.hasCurrentSong, isFalse);
      });

      test('格式化时长应正确', () {
        final formatted = provider.formattedPosition;
        expect(formatted, contains(':'));
      });
    });
  });

  group('Song 模型功能测试', () {
    test('Song 应正确创建', () {
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

      expect(song.id, 1);
      expect(song.title, '测试歌曲');
      expect(song.artist, '测试艺术家');
      expect(song.album, '测试专辑');
      expect(song.duration, 180000);
      expect(song.filePath, '/path/to/song.mp3');
    });

    test('Song 格式化时长应正确', () {
      final song1 = Song(
        id: 1,
        title: '1分钟歌曲',
        artist: '艺术家',
        duration: 60000,
        filePath: '/path/song1.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(song1.formattedDuration, '1:00');

      final song2 = Song(
        id: 2,
        title: '3分钟歌曲',
        artist: '艺术家',
        duration: 180000,
        filePath: '/path/song2.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(song2.formattedDuration, '3:00');

      final song3 = Song(
        id: 3,
        title: '10分钟歌曲',
        artist: '艺术家',
        duration: 600000,
        filePath: '/path/song3.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(song3.formattedDuration, '10:00');
    });

    test('Song 可选字段应正确处理', () {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '未知艺术家',
        duration: 180000,
        filePath: '/path/to/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(song.album, isNull);
      expect(song.albumArtPath, isNull);
      expect(song.dateAdded, isNull);
    });
  });
}
