import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysic_flutter/shared/widgets/bottom_sheet.dart';
import 'package:mysic_flutter/shared/widgets/delete_confirm_sheet.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

void main() {
  // 初始化 SharedPreferences mock
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AddToPlaylistSheet', () {
    Future<void> pumpAddToPlaylistSheet(
      WidgetTester tester, {
      List<Playlist> playlists = const [],
      Song? song,
      void Function(Playlist)? onPlaylistSelected,
      VoidCallback? onCreatePlaylist,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddToPlaylistSheet(
              playlists: playlists,
              song: song,
              onPlaylistSelected: onPlaylistSelected,
              onCreatePlaylist: onCreatePlaylist,
            ),
          ),
        ),
      );
    }

    testWidgets('should render create playlist button', (tester) async {
      await pumpAddToPlaylistSheet(tester);

      expect(find.text('创建新歌单'), findsOneWidget);
    });

    testWidgets('should render empty state when no playlists', (tester) async {
      await pumpAddToPlaylistSheet(tester, playlists: []);

      expect(find.text('暂无歌单'), findsOneWidget);
      expect(find.text('点击上方按钮创建新歌单'), findsOneWidget);
    });

    testWidgets('should render playlists list', (tester) async {
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Playlist(
          id: 2,
          name: '运动歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await pumpAddToPlaylistSheet(tester, playlists: playlists);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
      expect(find.text('运动歌单'), findsOneWidget);
    });

    testWidgets('should call onCreatePlaylist when create button tapped', (tester) async {
      bool createTapped = false;

      await pumpAddToPlaylistSheet(
        tester,
        onCreatePlaylist: () => createTapped = true,
      );

      await tester.tap(find.text('创建新歌单'));
      await tester.pumpAndSettle();

      expect(createTapped, isTrue);
    });

    testWidgets('should call onPlaylistSelected when playlist tapped', (tester) async {
      Playlist? selectedPlaylist;
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await pumpAddToPlaylistSheet(
        tester,
        playlists: playlists,
        onPlaylistSelected: (playlist) => selectedPlaylist = playlist,
      );

      await tester.tap(find.text('我喜欢的音乐'));
      await tester.pumpAndSettle();

      expect(selectedPlaylist, isNotNull);
      expect(selectedPlaylist?.id, 1);
    });

    testWidgets('should display song info when song provided', (tester) async {
      final song = Song(
        id: 1,
        title: 'Test Song',
        artist: 'Test Artist',
        filePath: '/path/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpAddToPlaylistSheet(tester, song: song);

      expect(find.text('Test Song'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
    });
  });

  group('PlaylistOptionsSheet', () {
    Future<void> pumpPlaylistOptionsSheet(
      WidgetTester tester, {
      required Playlist playlist,
      VoidCallback? onEdit,
      VoidCallback? onDelete,
      VoidCallback? onRename,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistOptionsSheet(
              playlist: playlist,
              onEdit: onEdit,
              onDelete: onDelete,
              onRename: onRename,
            ),
          ),
        ),
      );
    }

    testWidgets('should render playlist name', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(tester, playlist: playlist);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
    });

    testWidgets('should render all options', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(tester, playlist: playlist);

      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('编辑歌曲'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('删除歌单'), findsOneWidget);
    });

    testWidgets('should call onRename when rename tapped', (tester) async {
      bool renameTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(
        tester,
        playlist: playlist,
        onRename: () => renameTapped = true,
      );

      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      expect(renameTapped, isTrue);
    });

    testWidgets('should call onEdit when edit tapped', (tester) async {
      bool editTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(
        tester,
        playlist: playlist,
        onEdit: () => editTapped = true,
      );

      await tester.tap(find.text('编辑歌曲'));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });

    testWidgets('should call onDelete when delete tapped', (tester) async {
      bool deleteTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(
        tester,
        playlist: playlist,
        onDelete: () => deleteTapped = true,
      );

      await tester.tap(find.text('删除歌单'));
      await tester.pumpAndSettle();

      expect(deleteTapped, isTrue);
    });
  });

  group('CreatePlaylistDialog', () {
    Future<void> pumpCreatePlaylistDialog(
      WidgetTester tester, {
      Future<void> Function(String name, String? description, List<Song>? scannedSongs, String? scannedDirectory)? onCreate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreatePlaylistDialog(onCreate: onCreate),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
    }

    testWidgets('should render dialog title', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('创建歌单'), findsOneWidget);
    });

    testWidgets('should render input fields', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('歌单名称'), findsOneWidget);
      expect(find.text('描述（可选）'), findsOneWidget);
    });

    testWidgets('should have disabled create button initially', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '创建'),
      );

      expect(createButton.enabled, isFalse);
    });

    testWidgets('should enable create button when name entered', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      await tester.enterText(find.byType(TextField).first, '新歌单');
      await tester.pump();

      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '创建'),
      );

      expect(createButton.enabled, isTrue);
    });

    testWidgets('should call onCreate with name when create tapped', (tester) async {
      String? createdName;
      String? createdDescription;
      List<Song>? createdSongs;

      await pumpCreatePlaylistDialog(
        tester,
        onCreate: (name, description, scannedSongs, scannedDirectory) async {
          createdName = name;
          createdDescription = description;
          createdSongs = scannedSongs;
        },
      );

      await tester.enterText(find.byType(TextField).first, '新歌单');
      await tester.pump();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(createdName, '新歌单');
      expect(createdDescription, isNull);
      expect(createdSongs, isNull);
    });

    testWidgets('should call onCreate with description when provided', (tester) async {
      String? createdName;
      String? createdDescription;
      List<Song>? createdSongs;

      await pumpCreatePlaylistDialog(
        tester,
        onCreate: (name, description, scannedSongs, scannedDirectory) async {
          createdName = name;
          createdDescription = description;
          createdSongs = scannedSongs;
        },
      );

      await tester.enterText(find.byType(TextField).first, '新歌单');
      await tester.enterText(find.byType(TextField).last, '歌单描述');
      await tester.pump();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(createdName, '新歌单');
      expect(createdDescription, '歌单描述');
      expect(createdSongs, isNull); // 没有选择目录时为 null
    });

    testWidgets('should close dialog when cancel tapped', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('创建歌单'), findsNothing);
    });
  });

  group('CreatePlaylistDialog with directory selection', () {
    Future<void> pumpCreatePlaylistDialog(
      WidgetTester tester, {
      Future<void> Function(String name, String? description, List<Song>? scannedSongs, String? scannedDirectory)? onCreate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreatePlaylistDialog(onCreate: onCreate),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
    }

    testWidgets('should render directory selection field', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('扫描目录（可选）'), findsOneWidget);
      expect(find.text('选择'), findsOneWidget);
    });

    testWidgets('should show placeholder when no directory selected', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('未选择目录'), findsOneWidget);
    });
  });

  group('DeleteConfirmSheet', () {
    testWidgets('显示删除确认弹窗和勾选框', (tester) async {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        filePath: '/test/path.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (_) {},
            ),
          ),
        ),
      );

      // 等待异步加载完成
      await tester.pumpAndSettle();

      // 验证标题显示
      expect(find.text('确认删除歌曲？'), findsOneWidget);
      expect(find.text('测试歌曲'), findsOneWidget);
      expect(find.text('同时删除原文件'), findsOneWidget);
    });

    testWidgets('显示歌曲信息', (tester) async {
      final song = Song(
        id: 1,
        title: '我的歌曲',
        artist: '艺术家名称',
        filePath: '/test/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证歌曲标题显示
      expect(find.text('我的歌曲'), findsOneWidget);
    });

    testWidgets('显示操作按钮', (tester) async {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        filePath: '/test/path.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证按钮显示
      expect(find.text('算了吧'), findsOneWidget);
      expect(find.text('删了吧'), findsOneWidget);
    });

    testWidgets('显示警告提示', (tester) async {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        filePath: '/test/path.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证警告提示显示
      expect(
        find.text('删除后歌曲将从所有歌单移除，且不会在下次扫描时重新添加'),
        findsOneWidget,
      );
    });

    testWidgets('点击删除按钮调用 onConfirm 回调（默认不删除文件）', (tester) async {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        filePath: '/test/path.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool? receivedDeleteWithFile;
      bool onConfirmCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (deleteWithFile) {
                onConfirmCalled = true;
                receivedDeleteWithFile = deleteWithFile;
              },
            ),
          ),
        ),
      );

      // 等待异步加载完成
      await tester.pumpAndSettle();

      // 点击删除按钮
      await tester.tap(find.text('删了吧'));
      await tester.pumpAndSettle();

      // 验证 onConfirm 被调用，且 deleteWithFile 为 false（默认值）
      expect(onConfirmCalled, isTrue);
      expect(receivedDeleteWithFile, isFalse);
    });

    testWidgets('勾选复选框后点击删除按钮调用 onConfirm 回调（删除文件）', (tester) async {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        filePath: '/test/path.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool? receivedDeleteWithFile;
      bool onConfirmCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (deleteWithFile) {
                onConfirmCalled = true;
                receivedDeleteWithFile = deleteWithFile;
              },
            ),
          ),
        ),
      );

      // 等待异步加载完成
      await tester.pumpAndSettle();

      // 找到 CheckboxListTile 并点击切换状态
      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // 点击删除按钮
      await tester.tap(find.text('删了吧'));
      await tester.pumpAndSettle();

      // 验证 onConfirm 被调用，且 deleteWithFile 为 true
      expect(onConfirmCalled, isTrue);
      expect(receivedDeleteWithFile, isTrue);
    });

    testWidgets('点击取消按钮不调用 onConfirm 回调', (tester) async {
      final song = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        filePath: '/test/path.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool onConfirmCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmSheet(
              song: song,
              onConfirm: (_) {
                onConfirmCalled = true;
              },
            ),
          ),
        ),
      );

      // 等待异步加载完成
      await tester.pumpAndSettle();

      // 点击取消按钮
      await tester.tap(find.text('算了吧'));
      await tester.pumpAndSettle();

      // 验证 onConfirm 未被调用
      expect(onConfirmCalled, isFalse);
    });
  });
}
