import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/lyrics_cache.dart';

void main() {
  group('LyricsCache', () {
    test('精确匹配歌词文件', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'song1', 'song2'});

      expect(cache.findLyricsPath('/music/album/song1.mp3'), '/music/album/song1.lrc');
      expect(cache.findLyricsPath('/music/album/song2.flac'), '/music/album/song2.lrc');
    });

    test('宽松匹配忽略序号前缀', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'01 - song name'});

      // 音频文件名无序号，歌词文件有序号
      expect(cache.findLyricsPath('/music/album/song name.mp3'), '/music/album/01 - song name.lrc');

      // 音频文件名有序号，歌词文件无序号
      cache.addDirectory('/music/album2', {'song name'});
      expect(cache.findLyricsPath('/music/album2/02. song name.mp3'), '/music/album2/song name.lrc');
    });

    test('找不到歌词返回 null', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'other'});

      expect(cache.findLyricsPath('/music/album/song.mp3'), null);
      expect(cache.findLyricsPath('/music/other/song.mp3'), null);
    });

    test('处理不同分隔符的序号前缀', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'song'});

      expect(cache.findLyricsPath('/music/album/01 - song.mp3'), '/music/album/song.lrc');
      expect(cache.findLyricsPath('/music/album/02.song.mp3'), '/music/album/song.lrc');
      expect(cache.findLyricsPath('/music/album/03_song.mp3'), '/music/album/song.lrc');
    });
  });
}
