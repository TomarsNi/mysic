# API 设置功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Mysic 音乐播放器添加 API 配置功能，支持配置多个大模型服务商的 API 信息，单选启用。

**Architecture:** 采用分层架构：数据模型 → Repository → Provider → UI 页面。数据存储在 SQLite 数据库的新建 api_configs 表中。

**Tech Stack:** Flutter, Provider, SQLite (sqflite), 遵循项目现有架构模式

---

## 文件结构

```
lib/features/settings/
├── data/
│   ├── models/
│   │   └── api_config.dart              # 新建：API 配置数据模型
│   └── repositories/
│       └── api_config_repository.dart    # 新建：数据库操作层
├── presentation/
│   ├── providers/
│   │   └── api_config_provider.dart      # 新建：状态管理
│   └── pages/
│       └── api_settings_page.dart        # 新建：API 设置页面

需要修改的文件：
- lib/core/database/database_helper.dart   # 添加新表
- lib/shared/widgets/app_drawer.dart       # 添加入口按钮
- lib/main.dart                            # 注册 Provider
```

---

### Task 1: 数据模型 ApiConfig

**Files:**
- Create: `lib/features/settings/data/models/api_config.dart`

- [ ] **Step 1: 创建 ApiConfig 数据模型**

```dart
import 'package:flutter/foundation.dart';

/// API 服务商类型
enum ApiProvider {
  aliyun,
  zhipu,
  xunfei,
  tencent,
}

/// API 服务商配置扩展
extension ApiProviderExtension on ApiProvider {
  /// 服务商显示名称
  String get displayName {
    switch (this) {
      case ApiProvider.aliyun:
        return '阿里云百炼';
      case ApiProvider.zhipu:
        return '智谱 AI';
      case ApiProvider.xunfei:
        return '讯飞星火';
      case ApiProvider.tencent:
        return '腾讯混元';
    }
  }

  /// 服务商描述
  String get description {
    switch (this) {
      case ApiProvider.aliyun:
        return '通义千问系列模型';
      case ApiProvider.zhipu:
        return 'GLM 系列模型';
      case ApiProvider.xunfei:
        return 'Spark 系列模型';
      case ApiProvider.tencent:
        return 'Hunyuan 系列模型';
    }
  }

  /// 默认 API URL
  String get defaultApiUrl {
    switch (this) {
      case ApiProvider.aliyun:
        return 'https://dashscope.aliyuncs.com/api/v1';
      case ApiProvider.zhipu:
        return 'https://open.bigmodel.cn/api/paas/v4';
      case ApiProvider.xunfei:
        return 'https://spark-api-open.xf-yun.com/v1';
      case ApiProvider.tencent:
        return 'https://api.hunyuan.cloud.tencent.com/v1';
    }
  }

  /// 默认模型名称
  String get defaultModelName {
    switch (this) {
      case ApiProvider.aliyun:
        return 'qwen-plus';
      case ApiProvider.zhipu:
        return 'glm-4';
      case ApiProvider.xunfei:
        return 'spark-4.0-ultra';
      case ApiProvider.tencent:
        return 'hunyuan-lite';
    }
  }

  /// 从字符串解析
  static ApiProvider? fromString(String value) {
    return switch (value) {
      'aliyun' => ApiProvider.aliyun,
      'zhipu' => ApiProvider.zhipu,
      'xunfei' => ApiProvider.xunfei,
      'tencent' => ApiProvider.tencent,
      _ => null,
    };
  }

  /// 转换为字符串
  String toValueString() {
    return switch (this) {
      ApiProvider.aliyun => 'aliyun',
      ApiProvider.zhipu => 'zhipu',
      ApiProvider.xunfei => 'xunfei',
      ApiProvider.tencent => 'tencent',
    };
  }
}

/// API 配置模型
@immutable
class ApiConfig {
  final int? id;
  final ApiProvider provider;
  final String apiUrl;
  final String apiKey;
  final String modelName;
  final bool isEnabled;

  const ApiConfig({
    this.id,
    required this.provider,
    this.apiUrl = '',
    this.apiKey = '',
    this.modelName = '',
    this.isEnabled = false,
  });

  /// 是否已配置（所有必填项都有值）
  bool get isConfigured =>
      apiUrl.isNotEmpty && apiKey.isNotEmpty && modelName.isNotEmpty;

  /// 创建默认配置
  factory ApiConfig.defaultFor(ApiProvider provider) {
    return ApiConfig(
      provider: provider,
      apiUrl: provider.defaultApiUrl,
      apiKey: '',
      modelName: provider.defaultModelName,
    );
  }

  /// 复制并修改
  ApiConfig copyWith({
    int? id,
    ApiProvider? provider,
    String? apiUrl,
    String? apiKey,
    String? modelName,
    bool? isEnabled,
  }) {
    return ApiConfig(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// 转换为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider.toValueString(),
      'api_url': apiUrl,
      'api_key': apiKey,
      'model_name': modelName,
      'is_enabled': isEnabled ? 1 : 0,
    };
  }

  /// 从 Map 解析
  factory ApiConfig.fromMap(Map<String, dynamic> map) {
    final providerStr = map['provider'] as String;
    final provider = ApiProviderExtension.fromString(providerStr);

    if (provider == null) {
      throw ArgumentError('Unknown provider: $providerStr');
    }

    return ApiConfig(
      id: map['id'] as int?,
      provider: provider,
      apiUrl: map['api_url'] as String? ?? '',
      apiKey: map['api_key'] as String? ?? '',
      modelName: map['model_name'] as String? ?? '',
      isEnabled: map['is_enabled'] == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiConfig &&
        other.id == id &&
        other.provider == provider &&
        other.apiUrl == apiUrl &&
        other.apiKey == apiKey &&
        other.modelName == modelName &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(id, provider, apiUrl, apiKey, modelName, isEnabled);
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `ls mysic_flutter/lib/features/settings/data/models/`
Expected: `api_config.dart` 文件存在

---

### Task 2: 数据库迁移

**Files:**
- Modify: `lib/core/database/database_helper.dart`

- [ ] **Step 1: 添加表名常量和版本号更新**

在 `database_helper.dart` 中修改：

```dart
// 在第 27 行后添加表名常量
static const String tableApiConfigs = 'api_configs';

// 修改数据库版本（第 19 行）
static const int _databaseVersion = 5;
```

- [ ] **Step 2: 在 _onCreate 方法中添加建表语句**

在 `_onCreate` 方法的最后（第 151 行后）添加：

```dart
// 创建 API 配置表
await db.execute('''
  CREATE TABLE $tableApiConfigs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL UNIQUE,
    api_url TEXT,
    api_key TEXT,
    model_name TEXT,
    is_enabled INTEGER NOT NULL DEFAULT 0
  )
''');

// 创建索引
await db.execute('''
  CREATE INDEX idx_api_configs_provider ON $tableApiConfigs (provider)
''');
```

- [ ] **Step 3: 在 _onUpgrade 方法中添加迁移逻辑**

在 `_onUpgrade` 方法的最后（第 270 行后）添加：

```dart
// 版本 4 -> 5: 新增 api_configs 表
if (oldVersion < 5) {
  await db.execute('''
    CREATE TABLE $tableApiConfigs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      provider TEXT NOT NULL UNIQUE,
      api_url TEXT,
      api_key TEXT,
      model_name TEXT,
      is_enabled INTEGER NOT NULL DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_api_configs_provider ON $tableApiConfigs (provider)
  ''');
}
```

- [ ] **Step 4: 验证数据库迁移**

Run: `cd mysic_flutter && flutter analyze lib/core/database/database_helper.dart`
Expected: No issues found

---

### Task 3: Repository 数据访问层

**Files:**
- Create: `lib/features/settings/data/repositories/api_config_repository.dart`

- [ ] **Step 1: 创建 ApiConfigRepository**

```dart
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/api_config.dart';

/// API 配置数据访问层
class ApiConfigRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 获取所有配置
  Future<List<ApiConfig>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableApiConfigs,
      orderBy: 'id ASC',
    );
    return maps.map((map) => ApiConfig.fromMap(map)).toList();
  }

  /// 按服务商获取配置
  Future<ApiConfig?> getByProvider(ApiProvider provider) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableApiConfigs,
      where: 'provider = ?',
      whereArgs: [provider.toValueString()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ApiConfig.fromMap(maps.first);
  }

  /// 获取已启用的配置
  Future<ApiConfig?> getEnabled() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableApiConfigs,
      where: 'is_enabled = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ApiConfig.fromMap(maps.first);
  }

  /// 保存配置（插入或更新）
  Future<void> save(ApiConfig config) async {
    final db = await _dbHelper.database;

    if (config.id != null) {
      // 更新现有记录
      await db.update(
        DatabaseHelper.tableApiConfigs,
        config.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [config.id],
      );
    } else {
      // 检查是否已存在该服务商的配置
      final existing = await getByProvider(config.provider);
      if (existing != null) {
        // 更新现有记录
        await db.update(
          DatabaseHelper.tableApiConfigs,
          config.toMap()..remove('id'),
          where: 'provider = ?',
          whereArgs: [config.provider.toValueString()],
        );
      } else {
        // 插入新记录
        await db.insert(
          DatabaseHelper.tableApiConfigs,
          config.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  /// 启用指定服务商（自动禁用其他）
  Future<void> enableOnly(ApiProvider provider) async {
    final db = await _dbHelper.database;

    // 使用事务确保原子性
    await db.transaction((txn) async {
      // 禁用所有
      await txn.update(
        DatabaseHelper.tableApiConfigs,
        {'is_enabled': 0},
      );

      // 启用指定服务商
      await txn.update(
        DatabaseHelper.tableApiConfigs,
        {'is_enabled': 1},
        where: 'provider = ?',
        whereArgs: [provider.toValueString()],
      );
    });
  }

  /// 禁用所有配置
  Future<void> disableAll() async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableApiConfigs,
      {'is_enabled': 0},
    );
  }

  /// 删除配置
  Future<void> delete(ApiProvider provider) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableApiConfigs,
      where: 'provider = ?',
      whereArgs: [provider.toValueString()],
    );
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/features/settings/data/repositories/api_config_repository.dart`
Expected: No issues found

---

### Task 4: Provider 状态管理

**Files:**
- Create: `lib/features/settings/presentation/providers/api_config_provider.dart`

- [ ] **Step 1: 创建 ApiConfigProvider**

```dart
import 'package:flutter/foundation.dart';
import '../../data/models/api_config.dart';
import '../../data/repositories/api_config_repository.dart';

/// API 配置状态管理
class ApiConfigProvider extends ChangeNotifier {
  final ApiConfigRepository _repository = ApiConfigRepository();

  /// 所有配置列表
  List<ApiConfig> _configs = [];
  List<ApiConfig> get configs => List.unmodifiable(_configs);

  /// 当前启用的配置
  ApiConfig? _enabledConfig;
  ApiConfig? get enabledConfig => _enabledConfig;

  /// 是否已加载
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// 加载所有配置
  Future<void> load() async {
    _configs = await _repository.getAll();
    _enabledConfig = await _repository.getEnabled();
    _isLoaded = true;
    notifyListeners();
  }

  /// 确保所有服务商都有默认配置
  Future<void> ensureDefaultConfigs() async {
    final existingProviders = _configs.map((c) => c.provider).toSet();

    for (final provider in ApiProvider.values) {
      if (!existingProviders.contains(provider)) {
        final defaultConfig = ApiConfig.defaultFor(provider);
        await _repository.save(defaultConfig);
      }
    }

    // 重新加载
    await load();
  }

  /// 获取指定服务商的配置
  ApiConfig? getConfig(ApiProvider provider) {
    try {
      return _configs.firstWhere((c) => c.provider == provider);
    } catch (_) {
      return null;
    }
  }

  /// 保存配置
  Future<void> save(ApiConfig config) async {
    await _repository.save(config);
    await load();
  }

  /// 切换启用状态
  /// 返回是否成功（配置不完整时返回 false）
  Future<bool> toggleEnable(ApiProvider provider) async {
    final config = getConfig(provider);

    if (config == null) return false;

    if (config.isEnabled) {
      // 当前已启用，禁用它
      await _repository.disableAll();
    } else {
      // 当前未启用，检查配置是否完整
      if (!config.isConfigured) {
        return false;
      }
      // 启用它
      await _repository.enableOnly(provider);
    }

    await load();
    return true;
  }

  /// 更新配置字段
  Future<void> updateConfig(
    ApiProvider provider, {
    String? apiUrl,
    String? apiKey,
    String? modelName,
  }) async {
    var config = getConfig(provider);
    if (config == null) {
      config = ApiConfig.defaultFor(provider);
    }

    final updatedConfig = config.copyWith(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );

    await _repository.save(updatedConfig);
    await load();
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/features/settings/presentation/providers/api_config_provider.dart`
Expected: No issues found

---

### Task 5: API 设置页面 UI

**Files:**
- Create: `lib/features/settings/presentation/pages/api_settings_page.dart`

- [ ] **Step 1: 创建 ApiSettingsPage**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/api_config.dart';
import '../providers/api_config_provider.dart';

/// API 设置页面
class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfigs();
    });
  }

  Future<void> _loadConfigs() async {
    final provider = context.read<ApiConfigProvider>();
    if (!provider.isLoaded) {
      await provider.load();
    }
    await provider.ensureDefaultConfigs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Column(
        children: [
          Text(
            '设置',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          Text(
            'API 配置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<ApiConfigProvider>(
      builder: (context, provider, child) {
        if (!provider.isLoaded) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提示信息卡片
              _buildTipCard(context),

              const SizedBox(height: 20),

              // 服务商配置卡片列表
              ...ApiProvider.values.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ApiConfigCard(
                    config: provider.getConfigs(provider.configs),
                    onSave: (config) => _saveConfig(config),
                    onToggleEnable: (p) => _toggleEnable(p),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '配置大模型 API 后，可使用 AI 功能（如智能歌词翻译、音乐推荐等）。只能启用一个服务商。',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig(ApiConfig config) async {
    final provider = context.read<ApiConfigProvider>();
    await provider.save(config);
  }

  Future<void> _toggleEnable(ApiProvider provider) async {
    final configProvider = context.read<ApiConfigProvider>();
    final success = await configProvider.toggleEnable(provider);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先完成所有配置项'),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API 配置已启用'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// API 配置卡片组件
class _ApiConfigCard extends StatefulWidget {
  final ApiConfig config;
  final void Function(ApiConfig config) onSave;
  final void Function(ApiProvider provider) onToggleEnable;

  const _ApiConfigCard({
    required this.config,
    required this.onSave,
    required this.onToggleEnable,
  });

  @override
  State<_ApiConfigCard> createState() => _ApiConfigCardState();
}

class _ApiConfigCardState extends State<_ApiConfigCard> {
  bool _isExpanded = false;
  late TextEditingController _urlController;
  late TextEditingController _keyController;
  late TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.config.apiUrl);
    _keyController = TextEditingController(text: widget.config.apiKey);
    _modelController = TextEditingController(text: widget.config.modelName);
  }

  @override
  void didUpdateWidget(covariant _ApiConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _urlController.text = widget.config.apiUrl;
      _keyController.text = widget.config.apiKey;
      _modelController.text = widget.config.modelName;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 头部
          _buildHeader(context),

          // 展开内容
          if (_isExpanded) _buildExpandedContent(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: _getGradientForProvider(widget.config.provider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getShortName(widget.config.provider),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 名称和描述
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.config.provider.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.config.provider.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // 状态
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 12,
                color: widget.config.isEnabled
                    ? AppColors.accent
                    : AppColors.muted,
              ),
            ),

            const SizedBox(width: 8),

            // 展开箭头
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.muted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // API URL 输入框
          _buildInputField(
            label: 'API URL',
            controller: _urlController,
            placeholder: widget.config.provider.defaultApiUrl,
          ),

          const SizedBox(height: 12),

          // API Key 输入框
          _buildInputField(
            label: 'API Key',
            controller: _keyController,
            placeholder: '请输入 API Key',
            isPassword: true,
          ),

          const SizedBox(height: 12),

          // 模型名称输入框
          _buildInputField(
            label: '模型名称',
            controller: _modelController,
            placeholder: widget.config.provider.defaultModelName,
          ),

          const SizedBox(height: 16),

          // 启用开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '启用此配置',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
              _buildToggleSwitch(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 14, color: AppColors.white),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              fontSize: 14,
              color: AppColors.muted.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (_) => _saveCurrentConfig(),
        ),
      ],
    );
  }

  Widget _buildToggleSwitch(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onToggleEnable(widget.config.provider),
      child: Container(
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: widget.config.isEnabled
              ? AppColors.accent
              : AppColors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          alignment: widget.config.isEnabled
              ? Alignment.centerRight
              : Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: widget.config.isEnabled
                  ? AppColors.white
                  : AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  void _saveCurrentConfig() {
    final updatedConfig = widget.config.copyWith(
      apiUrl: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
      modelName: _modelController.text.trim(),
    );
    widget.onSave(updatedConfig);
  }

  String _getStatusText() {
    if (widget.config.isEnabled) return '已启用';
    if (widget.config.isConfigured) return '已配置';
    return '未配置';
  }

  LinearGradient _getGradientForProvider(ApiProvider provider) {
    return switch (provider) {
      ApiProvider.aliyun => AppColors.orangeGradient,
      ApiProvider.zhipu => AppColors.blueGradient,
      ApiProvider.xunfei => AppColors.violetGradient,
      ApiProvider.tencent => AppColors.emeraldGradient,
    };
  }

  String _getShortName(ApiProvider provider) {
    return switch (provider) {
      ApiProvider.aliyun => '阿里',
      ApiProvider.zhipu => '智谱',
      ApiProvider.xunfei => '讯飞',
      ApiProvider.tencent => '腾讯',
    };
  }
}

/// ApiProvider 扩展方法
extension ApiConfigExtension on ApiProvider {
  ApiConfig? getConfigs(List<ApiConfig> configs) {
    try {
      return configs.firstWhere((c) => c.provider == this);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/features/settings/presentation/pages/api_settings_page.dart`
Expected: No issues found

---

### Task 6: 集成到 AppDrawer

**Files:**
- Modify: `lib/shared/widgets/app_drawer.dart`

- [ ] **Step 1: 添加 onApiSettingsTap 回调参数**

在 `AppDrawer` 类中添加参数（约第 27 行后）：

```dart
/// API 设置点击回调
final VoidCallback? onApiSettingsTap;
```

在构造函数中添加参数（约第 38 行后）：

```dart
this.onApiSettingsTap,
```

- [ ] **Step 2: 在 _buildFooter 方法中添加 API 设置按钮**

在 `_buildFooter` 方法的"关于按钮"后添加（约第 431 行后）：

```dart
const SizedBox(height: 8),

// API 设置按钮 - 设计稿：w-full bg-white/5 text-white/70
Material(
  color: Colors.white.withValues(alpha: 0.05),
  borderRadius: BorderRadius.circular(12),
  child: InkWell(
    onTap: () {
      Navigator.of(context).pop();
      onApiSettingsTap?.call();
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_suggest_rounded,
            size: 20,
            color: AppColors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            'API 设置',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    ),
  ),
),
```

- [ ] **Step 3: 验证修改**

Run: `cd mysic_flutter && flutter analyze lib/shared/widgets/app_drawer.dart`
Expected: No issues found

---

### Task 7: 注册 Provider 并添加导航

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 导入 ApiConfigProvider 和 ApiSettingsPage**

在文件顶部的导入区域添加（约第 12 行后）：

```dart
import 'features/settings/presentation/providers/api_config_provider.dart';
import 'features/settings/presentation/pages/api_settings_page.dart';
```

- [ ] **Step 2: 在 MultiProvider 中注册 ApiConfigProvider**

修改 `MysicApp` 的 `build` 方法中的 `MultiProvider`（约第 51-55 行）：

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => PlayerProvider()),
    ChangeNotifierProvider(create: (_) => PlaylistProvider()),
    ChangeNotifierProvider(create: (_) => ApiConfigProvider()),
  ],
  // ... 其余代码不变
);
```

- [ ] **Step 3: 在 HomePage 中添加 onApiSettingsTap 回调**

在 `HomePage` 的 `build` 方法中的 `AppDrawer` 添加回调（约第 174 行后）：

```dart
onApiSettingsTap: () => _showApiSettings(context),
```

- [ ] **Step 4: 添加 _showApiSettings 方法**

在 `HomePage` 类中添加方法（约第 691 行后）：

```dart
void _showApiSettings(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const ApiSettingsPage(),
    ),
  );
}
```

- [ ] **Step 5: 验证修改**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`
Expected: No issues found

---

### Task 8: 运行测试验证

- [ ] **Step 1: 运行 Flutter 分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 2: 运行应用测试**

Run: `cd mysic_flutter && flutter run -d windows`
Expected: 应用正常启动，抽屉菜单中显示"API 设置"按钮，点击可进入 API 设置页面

- [ ] **Step 3: 提交代码**

```bash
git add mysic_flutter/lib/features/settings/data/models/api_config.dart
git add mysic_flutter/lib/features/settings/data/repositories/api_config_repository.dart
git add mysic_flutter/lib/features/settings/presentation/providers/api_config_provider.dart
git add mysic_flutter/lib/features/settings/presentation/pages/api_settings_page.dart
git add mysic_flutter/lib/core/database/database_helper.dart
git add mysic_flutter/lib/shared/widgets/app_drawer.dart
git add mysic_flutter/lib/main.dart
git commit -m "feat: 添加 API 设置功能

- 新增 ApiConfig 数据模型
- 新增 api_configs 数据库表
- 新增 ApiConfigRepository 数据访问层
- 新增 ApiConfigProvider 状态管理
- 新增 ApiSettingsPage 设置页面
- 支持配置阿里云、智谱、讯飞、腾讯四个服务商
- 支持单选启用一个服务商"
```
