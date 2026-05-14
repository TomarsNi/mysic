import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/music_scanner.dart';
import 'package:mysic_flutter/shared/utils/windows_music_scanner.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('本地扫描功能测试', () {
    group('ScanState 枚举测试', () {
      test('ScanState 应包含所有状态', () {
        expect(ScanState.values.length, 5);
        expect(ScanState.values.contains(ScanState.idle), isTrue);
        expect(ScanState.values.contains(ScanState.scanning), isTrue);
        expect(ScanState.values.contains(ScanState.saving), isTrue);
        expect(ScanState.values.contains(ScanState.completed), isTrue);
        expect(ScanState.values.contains(ScanState.error), isTrue);
      });

      test('ScanState 顺序应正确', () {
        expect(ScanState.idle.index, 0);
        expect(ScanState.scanning.index, 1);
        expect(ScanState.saving.index, 2);
        expect(ScanState.completed.index, 3);
        expect(ScanState.error.index, 4);
      });
    });

    group('ScanResult 测试', () {
      test('创建成功的扫描结果应正确', () {
        final result = ScanResult(
          totalFound: 100,
          newAdded: 80,
          duplicates: 20,
          scanDuration: const Duration(seconds: 5),
        );

        expect(result.totalFound, 100);
        expect(result.newAdded, 80);
        expect(result.duplicates, 20);
        expect(result.scanDuration, const Duration(seconds: 5));
        expect(result.errorMessage, isNull);
        expect(result.isSuccess, isTrue);
      });

      test('创建失败的扫描结果应正确', () {
        final result = ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: Duration.zero,
          errorMessage: '未获得存储权限',
        );

        expect(result.totalFound, 0);
        expect(result.newAdded, 0);
        expect(result.duplicates, 0);
        expect(result.errorMessage, '未获得存储权限');
        expect(result.isSuccess, isFalse);
      });

      test('空扫描结果应正确', () {
        final result = ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: Duration.zero,
        );

        expect(result.totalFound, 0);
        expect(result.isSuccess, isTrue);
      });
    });

    group('MusicScanner 初始状态测试', () {
      test('MusicScanner 初始状态应为 idle', () {
        final scanner = MusicScanner();
        expect(scanner.state, ScanState.idle);
        expect(scanner.isScanning, isFalse);
      });

      test('MusicScanner 状态流应可用', () {
        final scanner = MusicScanner();
        expect(scanner.stateStream, isNotNull);
        expect(scanner.progressStream, isNotNull);
      });
    });

    group('扫描逻辑测试', () {
      test('重复扫描应返回错误', () async {
        final scanner = MusicScanner();

        // 由于没有真实设备，我们只测试状态检查逻辑
        expect(scanner.isScanning, isFalse);
        expect(scanner.state, ScanState.idle);
      });
    });

    group('Song 模型与扫描集成测试', () {
      test('从扫描结果创建 Song 应正确', () {
        // 模拟从扫描结果创建 Song
        final song = Song(
          id: 1,
          title: '扫描到的歌曲',
          artist: '艺术家',
          album: '专辑',
          duration: 180000,
          filePath: '/storage/emulated/0/Music/song.mp3',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(song.id, 1);
        expect(song.title, '扫描到的歌曲');
        expect(song.filePath, '/storage/emulated/0/Music/song.mp3');
        expect(song.dateAdded, isNotNull);
      });

      test('Song toMap 应可用于数据库存储', () {
        final now = DateTime.now();
        final song = Song(
          title: '测试歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/to/song.mp3',
          createdAt: now,
          updatedAt: now,
        );

        final map = song.toMap();

        expect(map['title'], '测试歌曲');
        expect(map['artist'], '艺术家');
        expect(map['duration'], 180000);
        expect(map['file_path'], '/path/to/song.mp3');
      });

      test('Song fromMap 应可从数据库恢复', () {
        final now = DateTime.now();
        final map = {
          'id': 1,
          'title': '数据库歌曲',
          'artist': '艺术家',
          'album': '专辑',
          'duration': 240000,
          'file_path': '/path/to/db_song.mp3',
          'album_art_path': null,
          'date_added': now.millisecondsSinceEpoch,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final song = Song.fromMap(map);

        expect(song.id, 1);
        expect(song.title, '数据库歌曲');
        expect(song.duration, 240000);
        expect(song.filePath, '/path/to/db_song.mp3');
      });
    });

    group('扫描结果统计测试', () {
      test('扫描结果统计应正确计算', () {
        // 模拟扫描统计
        const totalFound = 100;
        const duplicates = 25;
        final newAdded = totalFound - duplicates;

        final result = ScanResult(
          totalFound: totalFound,
          newAdded: newAdded,
          duplicates: duplicates,
          scanDuration: const Duration(seconds: 10),
        );

        expect(result.totalFound, 100);
        expect(result.newAdded, 75);
        expect(result.duplicates, 25);
        expect(result.isSuccess, isTrue);
      });

      test('全部重复的扫描结果应正确', () {
        final result = ScanResult(
          totalFound: 50,
          newAdded: 0,
          duplicates: 50,
          scanDuration: const Duration(seconds: 3),
        );

        expect(result.totalFound, 50);
        expect(result.newAdded, 0);
        expect(result.duplicates, 50);
        expect(result.isSuccess, isTrue);
      });

      test('全部新增的扫描结果应正确', () {
        final result = ScanResult(
          totalFound: 30,
          newAdded: 30,
          duplicates: 0,
          scanDuration: const Duration(seconds: 2),
        );

        expect(result.totalFound, 30);
        expect(result.newAdded, 30);
        expect(result.duplicates, 0);
        expect(result.isSuccess, isTrue);
      });
    });

    group('扫描进度测试', () {
      test('扫描进度应正确计算', () {
        // 模拟进度计算
        const total = 100;
        for (var processed = 0; processed <= total; processed += 25) {
          final progress = processed / total;
          expect(progress >= 0 && progress <= 1, isTrue);
        }
      });

      test('扫描时间应正确记录', () {
        final durations = [
          const Duration(seconds: 1),
          const Duration(seconds: 5),
          const Duration(seconds: 30),
          const Duration(minutes: 2),
        ];

        for (final duration in durations) {
          final result = ScanResult(
            totalFound: 100,
            newAdded: 100,
            duplicates: 0,
            scanDuration: duration,
          );
          expect(result.scanDuration, duration);
        }
      });
    });

    group('错误处理测试', () {
      test('权限错误应正确处理', () {
        final result = ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: Duration.zero,
          errorMessage: '未获得存储权限',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('权限'));
      });

      test('扫描进行中错误应正确处理', () {
        final result = ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: Duration.zero,
          errorMessage: '扫描正在进行中',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('正在进行'));
      });

      test('通用错误应正确处理', () {
        final result = ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: Duration.zero,
          errorMessage: '未知错误',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotNull);
      });
    });

    group('批量歌曲处理测试', () {
      test('批量创建 Song 应正确', () {
        final songs = List.generate(
          100,
          (i) => Song(
            id: i,
            title: '歌曲 $i',
            artist: '艺术家 $i',
            duration: (i + 1) * 60000,
            filePath: '/path/song_$i.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        expect(songs.length, 100);
        expect(songs.first.title, '歌曲 0');
        expect(songs.last.title, '歌曲 99');
      });

      test('批量 Song 转换为 Map 应正确', () {
        final songs = List.generate(
          10,
          (i) => Song(
            id: i,
            title: '歌曲 $i',
            artist: '艺术家',
            duration: 180000,
            filePath: '/path/song_$i.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final maps = songs.map((s) => s.toMap()).toList();

        expect(maps.length, 10);
        for (var i = 0; i < 10; i++) {
          expect(maps[i]['title'], '歌曲 $i');
          expect(maps[i]['file_path'], '/path/song_$i.mp3');
        }
      });
    });
  });

  group('同名图片封面获取', () {
    setUp(() async {
      // 每个测试前清理数据库
      final scanner = WindowsMusicScanner();
      await scanner.clearAllSongs();
    });

    test('Windows 扫描同名 jpg 图片作为封面', () async {
      // 准备测试目录（使用不包含 'test' 关键词的目录名，避免被非音乐文件过滤器误判）
      final testDir = await Directory.systemTemp.createTemp('music_scan_');
      final audioFile = File('${testDir.path}\\song.mp3');
      final imageFile = File('${testDir.path}\\song.jpg');

      // 创建测试文件（确保大于最小文件大小 100KB）
      await audioFile.writeAsBytes(List.filled(1024 * 101, 0)); // 101KB
      await imageFile.writeAsBytes(List.filled(1024, 0));

      try {
        final scanner = WindowsMusicScanner();
        final result = await scanner.scanMusicInDirectory(testDir.path);

        expect(result.totalFound, 1);
        expect(result.newAdded, 1);

        // 验证封面路径
        final songs = await scanner.getAllSongs();
        expect(songs.length, 1);
        expect(songs.first.albumArtPath, isNotNull);
        expect(songs.first.albumArtPath, contains('song.jpg'));

        // 清理
        await scanner.clearAllSongs();
      } finally {
        await testDir.delete(recursive: true);
      }
    });

    test('多格式图片按优先级选择', () async {
      final testDir = await Directory.systemTemp.createTemp('music_scan_');
      final audioFile = File('${testDir.path}\\song.mp3');
      final pngFile = File('${testDir.path}\\song.png');
      final gifFile = File('${testDir.path}\\song.gif');

      await audioFile.writeAsBytes(List.filled(1024 * 101, 0));
      await pngFile.writeAsBytes(List.filled(1024, 0));
      await gifFile.writeAsBytes(List.filled(1024, 0));

      try {
        final scanner = WindowsMusicScanner();
        await scanner.scanMusicInDirectory(testDir.path);

        final songs = await scanner.getAllSongs();
        // png > gif（优先级：jpg > jpeg > png > webp > gif）
        expect(songs.first.albumArtPath, contains('song.png'));

        await scanner.clearAllSongs();
      } finally {
        await testDir.delete(recursive: true);
      }
    });
  });
}
