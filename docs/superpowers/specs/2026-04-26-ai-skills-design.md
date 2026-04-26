# AI Skills 功能设计文档

## 概述

为 Mysic 音乐播放器添加 AI 智能功能，通过大模型联网搜索能力，帮助用户修正歌曲元数据（歌曲名、艺术家、专辑）和搜索匹配歌词。

## 功能范围

### 核心功能

1. **歌曲识别 Skill** - 通过文件名和现有元数据，识别正确的歌曲名称、艺术家、专辑
2. **歌词搜索 Skill** - 根据歌曲信息搜索匹配的 LRC 格式歌词

### 触发条件

- 用户已配置并启用大模型 API（阿里云百炼、智谱 AI、讯飞星火、腾讯混元）
- 当前有正在播放的歌曲

### 交互流程

1. 用户点击首页右上角魔法棒按钮
2. 弹出 Skill 选择菜单
3. 用户选择要执行的 Skill
4. 显示加载动画
5. AI 分析完成后显示预览界面
6. 用户确认后更新数据库

## 架构设计

### 目录结构

```
lib/features/ai_skills/
├── core/
│   ├── ai_skill.dart                     # Skill 抽象接口
│   ├── skill_result.dart                 # 统一结果模型
│   └── llm_service.dart                  # 大模型调用服务
├── skills/
│   ├── song_recognition/
│   │   ├── song_recognition_skill.dart   # 歌曲识别 Skill
│   │   └── recognition_result.dart       # 识别结果模型
│   └── lyrics_search/
│       ├── lyrics_search_skill.dart      # 歌词搜索 Skill
│       └── lyrics_result.dart            # 歌词结果模型
└── presentation/
    ├── providers/
    │   └── ai_skills_provider.dart       # Skill 状态管理
    └── widgets/
        ├── magic_wand_button.dart        # 魔法棒按钮
        ├── skill_selection_sheet.dart    # Skill 选择菜单
        └── result_preview_sheet.dart     # 结果预览界面
```

### 核心层

#### AiSkill 抽象接口

```dart
/// AI Skill 抽象接口
/// 所有 AI 功能必须实现此接口
abstract interface class AiSkill {
  /// Skill 唯一标识
  String get id;

  /// Skill 显示名称
  String get displayName;

  /// Skill 描述
  String get description;

  /// Skill 图标
  IconData get icon;

  /// 执行 Skill
  /// 返回 SkillResult 或抛出异常
  Future<SkillResult> execute({
    required ApiConfig config,
    required Map<String, dynamic> input,
  });
}
```

#### SkillResult 统一结果模型

```dart
/// Skill 执行结果基类
sealed class SkillResult {
  const SkillResult();
}

/// 成功结果
final class SkillSuccess extends SkillResult {
  const SkillSuccess(this.data);
  final Map<String, dynamic> data;
}

/// 失败结果
final class SkillFailure extends SkillResult {
  const SkillFailure(this.message, {this.error});
  final String message;
  final Object? error;
}

/// 无需修正（信息已正确）
final class SkillNoChange extends SkillResult {
  const SkillNoChange(this.message);
  final String message;
}
```

#### LlmService 大模型调用服务

```dart
/// 大模型调用服务
/// 封装各服务商的 API 调用逻辑
class LlmService {
  /// 发送聊天请求
  Future<String> chat({
    required ApiConfig config,
    required String prompt,
    bool enableWebSearch = false,
  });

  /// 构建请求 URL（根据服务商）
  String _buildUrl(ApiConfig config);

  /// 构建请求体（根据服务商）
  Map<String, dynamic> _buildRequestBody(
    ApiConfig config,
    String prompt,
    bool enableWebSearch,
  );

  /// 解析响应（根据服务商）
  String _parseResponse(ApiConfig config, Map<String, dynamic> response);
}
```

### Skill 层

#### Song Recognition Skill

**输入：**
- `filePath`: 歌曲文件路径
- `currentTitle`: 当前歌曲名（可选）
- `currentArtist`: 当前艺术家（可选）
- `currentAlbum`: 当前专辑（可选）

**输出：**
- `recognizedTitle`: 识别的歌曲名
- `recognizedArtist`: 识别的艺术家
- `recognizedAlbum`: 识别的专辑
- `confidence`: 置信度（high/medium/low）
- `source`: 信息来源（knowledge/web_search）
- `reason`: 判断依据

**Prompt 模板：**
```
请根据以下歌曲信息，识别正确的歌曲名称、艺术家和专辑名称。
如果信息可能不正确，请通过联网搜索验证。

当前信息：
- 文件名：{fileName}
- 歌曲名：{currentTitle}
- 艺术家：{currentArtist}
- 专辑：{currentAlbum}

请以 JSON 格式返回结果：
{
  "title": "正确的歌曲名",
  "artist": "正确的艺术家",
  "album": "正确的专辑",
  "confidence": "high/medium/low",
  "source": "knowledge/web_search",
  "reason": "简要说明判断依据"
}
```

#### Lyrics Search Skill

**输入：**
- `title`: 歌曲名
- `artist`: 艺术家
- `album`: 专辑（可选）

**输出：**
- `found`: 是否找到歌词
- `lyrics`: LRC 格式歌词内容
- `source`: 歌词来源
- `matchedSong`: 匹配的歌曲信息

**Prompt 模板：**
```
请搜索以下歌曲的 LRC 格式歌词（带时间轴）：
- 歌曲名：{title}
- 艺术家：{artist}
- 专辑：{album}

请通过联网搜索找到准确的歌词，并以 LRC 格式返回：
[00:00.00]第一行歌词
[00:05.00]第二行歌词
...

如果找不到歌词，请返回：
{
  "found": false,
  "reason": "未找到匹配歌词"
}

如果找到歌词，请返回：
{
  "found": true,
  "lyrics": "完整的LRC歌词内容",
  "source": "歌词来源网站",
  "matchedSong": {
    "title": "实际匹配的歌曲名",
    "artist": "实际匹配的艺术家"
  }
}
```

### 表示层

#### MagicWandButton

**位置：** 首页右上角，加号按钮左侧

**显示条件：** `ApiConfigProvider.enabledConfig` 不为 null

**交互：** 点击后弹出 `SkillSelectionSheet`

#### SkillSelectionSheet

显示可选 Skill 列表，用户选择后开始执行。

**UI 结构：**
- 标题：选择 AI 功能
- Skill 卡片列表（图标 + 名称 + 描述）
- 点击卡片开始执行对应 Skill

#### ResultPreviewSheet

**状态：**
1. 加载中 - 显示加载动画和提示文字
2. 识别成功（有变化）- 显示对比界面，用户可确认或取消
3. 识别成功（无变化）- 显示验证正确提示
4. 歌词搜索成功 - 显示歌词预览，用户可确认应用
5. 失败 - 显示错误信息

## 数据流

```
用户点击魔法棒
       │
       ▼
┌─────────────────┐
│ 检查 API 配置   │
└────────┬────────┘
         │
    有启用配置？
         │
    ┌────┴────┐
    │         │
   否         是
    │         │
    ▼         ▼
隐藏按钮   显示 Skill
          选择菜单
             │
             ▼
      用户选择 Skill
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
歌曲识别          歌词搜索
    │                 │
    ▼                 ▼
 构建请求          构建请求
    │                 │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────┐
    │   LlmService.chat   │
    │ (enableWebSearch)   │
    └──────────┬──────────┘
               │
               ▼
        ┌──────────────┐
        │ 解析 AI 响应 │
        └──────┬───────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
      成功          失败
        │             │
        ▼             ▼
    显示预览      显示错误
    界面          提示
        │
        ▼
    用户确认？
        │
    ┌───┴───┐
    │       │
    否      是
    │       │
    ▼       ▼
  关闭   更新数据库
         刷新 UI
```

## 状态管理

```dart
/// AI Skills 状态
class AiSkillsState {
  /// 当前执行的 Skill
  final AiSkill? currentSkill;

  /// 执行状态
  final SkillExecutionStatus status;

  /// 执行结果
  final SkillResult? result;

  /// 错误信息
  final String? errorMessage;
}

enum SkillExecutionStatus {
  idle,        // 空闲
  loading,     // 执行中
  success,     // 成功
  noChange,    // 无需修改
  failure,     // 失败
}
```

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| API 未配置 | 隐藏魔法棒按钮 |
| API 已配置但未启用 | 隐藏魔法棒按钮 |
| 无当前播放歌曲 | 点击魔法棒时提示"请先播放歌曲" |
| 网络请求超时 | 显示"网络超时，请重试"，允许重试 |
| API 返回错误 | 显示具体错误信息 |
| AI 返回格式错误 | 显示"解析失败"，显示原始响应 |
| 歌词搜索无结果 | 显示"未找到匹配歌词" |

## 数据库更新

### 歌曲识别成功

```dart
await db.update(
  'songs',
  {
    'title': result.title,
    'artist': result.artist,
    'album': result.album,
    'updated_at': DateTime.now().toIso8601String(),
  },
  where: 'id = ?',
  whereArgs: [song.id],
);
```

### 歌词搜索成功

```dart
await db.insert(
  'lyrics',
  {
    'song_id': song.id,
    'content': result.lyrics,
    'source': result.source,
    'created_at': DateTime.now().toIso8601String(),
  },
  conflictAlgorithm: ConflictAlgorithm.replace,
);
```

## 性能考虑

- **请求超时：** 30 秒
- **取消操作：** 用户可取消正在进行的请求

## 各服务商 API 适配

### 阿里云百炼

- **URL:** `https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation`
- **认证:** `Authorization: Bearer {apiKey}`
- **请求体格式:**
```json
{
  "model": "{modelName}",
  "input": {
    "messages": [{"role": "user", "content": "{prompt}"}]
  },
  "parameters": {
    "search_options": {"enable_search": true}
  }
}
```
- **联网搜索：** 通过 `search_options` 参数启用

### 智谱 AI

- **URL:** `https://open.bigmodel.cn/api/paas/v4/chat/completions`
- **认证:** `Authorization: Bearer {apiKey}`
- **请求体格式:**
```json
{
  "model": "{modelName}",
  "messages": [{"role": "user", "content": "{prompt}"}],
  "tools": [{"type": "web_search", "web_search": {"enable": true}}]
}
```
- **联网搜索：** 通过 `tools` 参数启用 `web_search`

### 讯飞星火

- **URL:** `https://spark-api-open.xf-yun.com/v1/chat/completions`
- **认证:** `Authorization: Bearer {apiKey}`
- **请求体格式:**
```json
{
  "model": "{modelName}",
  "messages": [{"role": "user", "content": "{prompt}"}],
  "functions": [{"name": "web_search"}]
}
```
- **联网搜索：** 通过 `functions` 参数启用

### 腾讯混元

- **URL:** `https://api.hunyuan.cloud.tencent.com/v1/chat/completions`
- **认证:** `Authorization: Bearer {apiKey}`
- **请求体格式:**
```json
{
  "model": "{modelName}",
  "messages": [{"role": "user", "content": "{prompt}"}],
  "enable_search": true
}
```
- **联网搜索：** 通过 `enable_search` 参数启用

## 实现优先级

1. **P0 - 核心功能**
   - LlmService 基础调用能力
   - Song Recognition Skill
   - Lyrics Search Skill
   - 魔法棒按钮和 Skill 选择菜单
   - 结果预览界面

2. **P1 - 体验优化**
   - 加载动画
   - 错误提示优化
   - 取消请求功能

3. **P2 - 可选功能**
   - 请求缓存（24 小时内不重复请求）
   - 批量处理模式
