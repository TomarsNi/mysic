# API 设置功能设计文档

## 概述

为 Mysic 音乐播放器添加 API 配置功能，允许用户配置多个大模型服务商的 API 信息，支持单选启用。

## 需求

- 支持配置 4 个服务商：阿里云百炼、智谱 AI、讯飞星火、腾讯混元
- 每个服务商配置项：API URL、API Key、模型名称
- 只能启用一个服务商
- 配置数据持久化存储

## 数据模型

### ApiConfig

```dart
// lib/features/settings/data/models/api_config.dart
class ApiConfig {
  final int? id;
  final String provider;      // 'aliyun' | 'zhipu' | 'xunfei' | 'tencent'
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

  ApiConfig copyWith({...});
  Map<String, dynamic> toMap();
  factory ApiConfig.fromMap(Map<String, dynamic> map);
}
```

## 数据库设计

### 新增表：api_configs

```sql
CREATE TABLE api_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider TEXT NOT NULL UNIQUE,
  api_url TEXT,
  api_key TEXT,
  model_name TEXT,
  is_enabled INTEGER NOT NULL DEFAULT 0
)
```

### 数据库版本升级

- 版本：4 → 5
- 迁移逻辑：在 `_onUpgrade` 中检测 `oldVersion < 5` 时创建表

## 架构设计

### 文件结构

```
lib/features/settings/
├── data/
│   ├── models/
│   │   └── api_config.dart
│   └── repositories/
│       └── api_config_repository.dart
├── presentation/
│   ├── providers/
│   │   └── api_config_provider.dart
│   └── pages/
│       └── api_settings_page.dart
```

### ApiConfigRepository

负责数据库 CRUD 操作：

- `Future<List<ApiConfig>> getAll()` — 获取所有配置
- `Future<ApiConfig?> getByProvider(String provider)` — 按服务商获取
- `Future<ApiConfig?> getEnabled()` — 获取已启用的配置
- `Future<void> save(ApiConfig config)` — 保存配置
- `Future<void> enableOnly(String provider)` — 启用指定服务商（自动禁用其他）

### ApiConfigProvider

状态管理，继承 ChangeNotifier：

- `List<ApiConfig> configs` — 所有配置列表
- `ApiConfig? enabledConfig` — 当前启用的配置
- `Future<void> load()` — 加载配置
- `Future<void> save(ApiConfig config)` — 保存配置
- `Future<void> toggleEnable(String provider)` — 切换启用状态

## UI 设计

### 页面结构

参考 `index.html` 第 426-632 行设计稿：

1. **顶部导航栏**
   - 返回按钮（左侧）
   - 标题 "API 配置"（居中）

2. **提示信息卡片**
   - 绿色边框背景
   - 图标 + 说明文字

3. **服务商配置卡片列表**
   - 可展开/折叠
   - 头部：图标 + 名称 + 状态 + 展开箭头
   - 展开内容：URL、Key、Model 输入框 + 启用开关

### 服务商配置

| 服务商 | provider | 图标背景色 | 默认 URL | 默认 Model |
|--------|----------|-----------|----------|-----------|
| 阿里云百炼 | aliyun | 橙红渐变 | https://dashscope.aliyuncs.com/api/v1 | qwen-plus |
| 智谱 AI | zhipu | 蓝青渐变 | https://open.bigmodel.cn/api/paas/v4 | glm-4 |
| 讯飞星火 | xunfei | 紫色渐变 | https://spark-api-open.xf-yun.com/v1 | spark-4.0-ultra |
| 腾讯混元 | tencent | 绿色渐变 | https://api.hunyuan.cloud.tencent.com/v1 | hunyuan-lite |

### 状态显示

- **未配置**：灰色文字，输入框有空项
- **已配置**：灰色文字，所有输入框已填写
- **已启用**：绿色文字，开关打开

### 交互逻辑

1. 点击卡片头部 → 展开/折叠配置区域
2. 输入内容 → 自动保存，更新状态显示
3. 点击启用开关：
   - 若配置不完整 → 显示 Toast 提示
   - 若配置完整 → 启用当前，禁用其他

## 入口集成

在 `AppDrawer` 底部区域添加 "API 设置" 按钮，点击后导航到 `ApiSettingsPage`。

设计稿参考：`index.html` 第 240-246 行。

## 测试要点

1. 数据库迁移正确执行
2. 配置保存和读取
3. 单选启用逻辑
4. UI 状态正确显示
5. 输入验证
