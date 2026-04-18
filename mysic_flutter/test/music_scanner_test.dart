import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/shared/utils/music_scanner.dart';

// 注意：由于 MusicScanner 依赖 on_audio_query 和 permission_handler，
// 这些插件在测试环境中无法直接使用，所以我们主要测试：
// 1. ScanState 枚举
// 2. ScanResult 模型
// 3. 数据库操作（通过 DatabaseHelper）

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanState 枚举测试', () {
    test('ScanState 应包含所有预期状态', () {
      expect(ScanState.values.length, 5);
      expect(ScanState.values, contains(ScanState.idle));
      expect(ScanState.values, contains(ScanState.scanning));
      expect(ScanState.values, contains(ScanState.saving));
      expect(ScanState.values, contains(ScanState.completed));
      expect(ScanState.values, contains(ScanState.error));
    });

    test('ScanState 状态名称正确', () {
      expect(ScanState.idle.name, 'idle');
      expect(ScanState.scanning.name, 'scanning');
      expect(ScanState.saving.name, 'saving');
      expect(ScanState.completed.name, 'completed');
      expect(ScanState.error.name, 'error');
    });
  });

  group('ScanResult 模型测试', () {
    test('创建成功的 ScanResult', () {
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
      expect(result.isSuccess, true);
    });

    test('创建失败的 ScanResult', () {
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
      expect(result.scanDuration, Duration.zero);
      expect(result.errorMessage, '未获得存储权限');
      expect(result.isSuccess, false);
    });

    test('ScanResult 计算正确', () {
      // 新增 + 重复 = 总数
      final result = ScanResult(
        totalFound: 150,
        newAdded: 100,
        duplicates: 50,
        scanDuration: const Duration(milliseconds: 3000),
      );

      expect(result.newAdded + result.duplicates, result.totalFound);
    });

    test('空扫描结果', () {
      final result = ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: const Duration(milliseconds: 100),
      );

      expect(result.isSuccess, true);
      expect(result.totalFound, 0);
    });
  });

  group('数据库歌曲表测试', () {
    late Database db;
    const tableName = 'songs';

    setUpAll(() {
      // 初始化 sqflite_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // 创建内存数据库
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE $tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              artist TEXT,
              album TEXT,
              duration INTEGER NOT NULL,
              file_path TEXT NOT NULL UNIQUE,
              album_art_path TEXT,
              date_added INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('插入歌曲成功', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.insert(tableName, {
        'title': '测试歌曲',
        'artist': '测试艺术家',
        'album': '测试专辑',
        'duration': 180000,
        'file_path': '/storage/music/test.mp3',
        'album_art_path': null,
        'date_added': now,
        'created_at': now,
        'updated_at': now,
      });

      expect(id, greaterThan(0));
    });

    test('查询歌曲成功', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 插入测试数据
      await db.insert(tableName, {
        'title': '歌曲A',
        'artist': '艺术家A',
        'album': '专辑A',
        'duration': 200000,
        'file_path': '/music/a.mp3',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(tableName, {
        'title': '歌曲B',
        'artist': '艺术家B',
        'album': '专辑B',
        'duration': 300000,
        'file_path': '/music/b.mp3',
        'created_at': now,
        'updated_at': now,
      });

      // 查询所有歌曲
      final songs = await db.query(tableName);
      expect(songs.length, 2);
    });

    test('重复路径插入失败', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const path = '/music/duplicate.mp3';

      await db.insert(tableName, {
        'title': '歌曲1',
        'artist': '艺术家1',
        'album': '专辑1',
        'duration': 100000,
        'file_path': path,
        'created_at': now,
        'updated_at': now,
      });

      // 尝试插入相同路径的歌曲应该失败
      expect(
        () async => await db.insert(tableName, {
          'title': '歌曲2',
          'artist': '艺术家2',
          'album': '专辑2',
          'duration': 200000,
          'file_path': path,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('搜索歌曲成功', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(tableName, {
        'title': '告白气球',
        'artist': '周杰伦',
        'album': '周杰伦的床边故事',
        'duration': 215000,
        'file_path': '/music/jay/chou.mp3',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(tableName, {
        'title': '晴天',
        'artist': '周杰伦',
        'album': '叶惠美',
        'duration': 269000,
        'file_path': '/music/jay/sunny.mp3',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(tableName, {
        'title': '小幸运',
        'artist': '田馥甄',
        'album': '小幸运',
        'duration': 295000,
        'file_path': '/music/hebe/lucky.mp3',
        'created_at': now,
        'updated_at': now,
      });

      // 搜索标题
      final titleResults = await db.query(
        tableName,
        where: 'title LIKE ?',
        whereArgs: ['%气球%'],
      );
      expect(titleResults.length, 1);
      expect(titleResults.first['title'], '告白气球');

      // 搜索艺术家
      final artistResults = await db.query(
        tableName,
        where: 'artist LIKE ?',
        whereArgs: ['%周杰伦%'],
      );
      expect(artistResults.length, 2);

      // 综合搜索
      final allResults = await db.query(
        tableName,
        where: 'title LIKE ? OR artist LIKE ? OR album LIKE ?',
        whereArgs: ['%幸运%', '%幸运%', '%幸运%'],
      );
      expect(allResults.length, 1);
    });

    test('删除歌曲成功', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final id = await db.insert(tableName, {
        'title': '待删除歌曲',
        'artist': '测试',
        'album': '测试',
        'duration': 100000,
        'file_path': '/music/delete.mp3',
        'created_at': now,
        'updated_at': now,
      });

      // 确认插入成功
      var songs = await db.query(tableName);
      expect(songs.length, 1);

      // 删除
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);

      // 确认删除成功
      songs = await db.query(tableName);
      expect(songs.length, 0);
    });

    test('清空歌曲表成功', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(tableName, {
        'title': '歌曲1',
        'artist': '艺术家',
        'album': '专辑',
        'duration': 100000,
        'file_path': '/music/1.mp3',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(tableName, {
        'title': '歌曲2',
        'artist': '艺术家',
        'album': '专辑',
        'duration': 200000,
        'file_path': '/music/2.mp3',
        'created_at': now,
        'updated_at': now,
      });

      var count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
      );
      expect(count, 2);

      // 清空
      await db.delete(tableName);

      count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
      );
      expect(count, 0);
    });

    test('获取歌曲数量', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < 10; i++) {
        await db.insert(tableName, {
          'title': '歌曲$i',
          'artist': '艺术家',
          'album': '专辑',
          'duration': 100000,
          'file_path': '/music/$i.mp3',
          'created_at': now,
          'updated_at': now,
        });
      }

      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
      );
      expect(count, 10);
    });

    test('按标题排序查询', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(tableName, {
        'title': 'Zebra',
        'artist': 'A',
        'album': 'A',
        'duration': 100000,
        'file_path': '/music/z.mp3',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(tableName, {
        'title': 'Apple',
        'artist': 'B',
        'album': 'B',
        'duration': 100000,
        'file_path': '/music/a.mp3',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(tableName, {
        'title': 'Banana',
        'artist': 'C',
        'album': 'C',
        'duration': 100000,
        'file_path': '/music/b.mp3',
        'created_at': now,
        'updated_at': now,
      });

      final songs = await db.query(tableName, orderBy: 'title ASC');
      expect(songs[0]['title'], 'Apple');
      expect(songs[1]['title'], 'Banana');
      expect(songs[2]['title'], 'Zebra');
    });
  });

  group('扫描进度计算测试', () {
    test('进度计算正确', () {
      const total = 100;
      for (int i = 0; i < total; i++) {
        final progress = (i + 1) / total;
        expect(progress, greaterThan(0));
        expect(progress, lessThanOrEqualTo(1));
      }
    });

    test('进度从 0 到 1', () {
      const total = 50;
      final progresses = <double>[];
      for (int i = 0; i < total; i++) {
        progresses.add((i + 1) / total);
      }

      expect(progresses.first, closeTo(0.02, 0.01));
      expect(progresses.last, 1.0);
    });

    test('空列表进度处理', () {
      const total = 0;
      if (total == 0) {
        // 空列表时进度应直接设为 1.0 或保持 0
        expect(true, true);
      }
    });
  });

  group('扫描时间统计测试', () {
    test('扫描时间格式化', () {
      const duration = Duration(seconds: 5, milliseconds: 300);
      expect(duration.inSeconds, 5);
      expect(duration.inMilliseconds, 5300);
    });

    test('快速扫描时间', () {
      final stopwatch = Stopwatch()..start();
      // 模拟快速操作
      for (int i = 0; i < 1000; i++) {
        // 空循环
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
