// test/features/ai_skills/skills/song_recognition_skill_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/ai_skills/skills/song_recognition/song_recognition_skill.dart';

void main() {
  group('SongRecognitionSkill', () {
    late SongRecognitionSkill skill;

    setUp(() {
      skill = SongRecognitionSkill();
    });

    test('has correct id', () {
      expect(skill.id, 'song_recognition');
    });

    test('has correct displayName', () {
      expect(skill.displayName, '识别歌曲信息');
    });

    test('has correct description', () {
      expect(skill.description, '识别歌曲名称、艺术家、专辑');
    });

    test('builds correct prompt from input', () {
      final prompt = skill.buildPrompt(
        filePath: '/music/晴天.mp3',
        currentTitle: '未知歌曲',
        currentArtist: '未知艺术家',
        currentAlbum: '未知专辑',
      );

      // 文件名不含扩展名（使用 basenameWithoutExtension）
      expect(prompt, contains('晴天'));
      expect(prompt, contains('未知歌曲'));
      expect(prompt, contains('未知艺术家'));
      expect(prompt, contains('未知专辑'));
      expect(prompt, contains('JSON'));
    });

    test('parses AI response correctly', () {
      const aiResponse = '''
根据文件名和联网搜索，识别结果如下：
{
  "title": "晴天",
  "artist": "周杰伦",
  "album": "叶惠美",
  "confidence": "high",
  "source": "web_search",
  "reason": "文件名与歌曲名匹配，通过搜索确认"
}
''';

      final result = skill.parseResponse(aiResponse);
      expect(result.title, '晴天');
      expect(result.artist, '周杰伦');
      expect(result.album, '叶惠美');
      expect(result.confidence, 'high');
    });
  });
}
