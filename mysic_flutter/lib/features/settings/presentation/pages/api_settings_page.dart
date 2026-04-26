import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/api_config.dart';
import '../providers/api_config_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// API 配置页面
/// 用户可以配置大模型服务商的 API 信息
class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  /// 当前展开的服务商
  ApiProvider? _expandedProvider;

  /// 文本输入控制器映射
  final Map<ApiProvider, _InputControllers> _controllers = {};

  @override
  void initState() {
    super.initState();
    // 初始化所有服务商的控制器
    for (final provider in ApiProvider.values) {
      _controllers[provider] = _InputControllers();
    }

    // 加载配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfigs();
    });
  }

  @override
  void dispose() {
    // 释放所有控制器
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 加载配置数据
  Future<void> _loadConfigs() async {
    final provider = context.read<ApiConfigProvider>();
    await provider.ensureDefaultConfigs();

    if (!mounted) return;

    // 更新控制器内容
    for (final apiProvider in ApiProvider.values) {
      final config = provider.getConfig(apiProvider);
      if (config != null) {
        final controllers = _controllers[apiProvider];
        controllers?.urlController.text = config.apiUrl;
        controllers?.keyController.text = config.apiKey;
        controllers?.modelController.text = config.modelName;
      }
    }
  }

  /// 保存配置
  Future<void> _saveConfig(ApiProvider provider) async {
    final controllers = _controllers[provider];
    if (controllers == null) return;

    final apiConfigProvider = context.read<ApiConfigProvider>();
    await apiConfigProvider.updateConfig(
      provider,
      apiUrl: controllers.urlController.text.trim(),
      apiKey: controllers.keyController.text.trim(),
      modelName: controllers.modelController.text.trim(),
    );
    // mounted check not needed here as we don't use context after await
  }

  /// 切换启用状态
  Future<void> _toggleEnable(ApiProvider provider) async {
    final apiConfigProvider = context.read<ApiConfigProvider>();
    final config = apiConfigProvider.getConfig(provider);

    // 检查配置是否完整
    if (config == null || !config.isConfigured) {
      _showToast('请先完成所有配置项');
      // 展开卡片
      setState(() {
        _expandedProvider = provider;
      });
      return;
    }

    final success = await apiConfigProvider.toggleEnable(provider);

    if (!mounted) return;

    if (!success && !config.isEnabled) {
      _showToast('请先完成所有配置项');
    } else if (config.isEnabled) {
      _showToast('已禁用 ${provider.displayName}');
    } else {
      _showToast('已启用 ${provider.displayName}');
    }
  }

  /// 显示 Toast 提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: Consumer<ApiConfigProvider>(
        builder: (context, provider, child) {
          if (!provider.isLoaded) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
              ),
            );
          }

          return _buildBody(provider);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
          Text(
            'API 配置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(ApiConfigProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 提示信息卡片
          _buildTipCard(),

          const SizedBox(height: 16),

          // 服务商配置卡片列表
          ...ApiProvider.values.map((apiProvider) {
            final config = provider.getConfig(apiProvider);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildProviderCard(apiProvider, config, provider),
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 提示信息卡片
  Widget _buildTipCard() {
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
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '配置大模型 API 后，可使用 AI 功能（如智能歌词翻译、音乐推荐等）。只能启用一个服务商。',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.accent.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 服务商配置卡片
  Widget _buildProviderCard(
    ApiProvider apiProvider,
    ApiConfig? config,
    ApiConfigProvider provider,
  ) {
    final isExpanded = _expandedProvider == apiProvider;
    final statusText = _getStatusText(config);
    final statusColor = _getStatusColor(config);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 卡片头部
          InkWell(
            onTap: () {
              setState(() {
                _expandedProvider = isExpanded ? null : apiProvider;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 渐变图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _getProviderGradient(apiProvider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getProviderShortName(apiProvider),
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
                          apiProvider.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          apiProvider.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 状态文字
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 展开箭头
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
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
          ),

          // 展开内容
          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.surface,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // URL 输入框
                  _buildInputField(
                    label: 'API URL',
                    controller: _controllers[apiProvider]?.urlController,
                    placeholder: apiProvider.defaultApiUrl,
                    onChanged: (_) => _saveConfig(apiProvider),
                  ),

                  const SizedBox(height: 16),

                  // Key 输入框
                  _buildInputField(
                    label: 'API Key',
                    controller: _controllers[apiProvider]?.keyController,
                    placeholder: _getKeyPlaceholder(apiProvider),
                    obscureText: true,
                    onChanged: (_) => _saveConfig(apiProvider),
                  ),

                  const SizedBox(height: 16),

                  // Model 输入框
                  _buildInputField(
                    label: '模型名称',
                    controller: _controllers[apiProvider]?.modelController,
                    placeholder: apiProvider.defaultModelName,
                    onChanged: (_) => _saveConfig(apiProvider),
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
                      _buildEnableToggle(apiProvider, config),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 输入框组件
  Widget _buildInputField({
    required String label,
    required TextEditingController? controller,
    required String placeholder,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
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
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.white,
          ),
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
              borderSide: BorderSide(
                color: AppColors.muted.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.muted.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// 启用开关
  Widget _buildEnableToggle(ApiProvider apiProvider, ApiConfig? config) {
    final isEnabled = config?.isEnabled ?? false;

    return GestureDetector(
      onTap: () => _toggleEnable(apiProvider),
      child: Container(
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.accent
              : AppColors.muted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isEnabled ? AppColors.white : AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// 获取服务商渐变色
  LinearGradient _getProviderGradient(ApiProvider provider) {
    return switch (provider) {
      ApiProvider.aliyun => AppColors.orangeGradient,
      ApiProvider.zhipu => AppColors.blueGradient,
      ApiProvider.xunfei => AppColors.violetGradient,
      ApiProvider.tencent => AppColors.emeraldGradient,
      ApiProvider.openai => AppColors.accentGradient,
    };
  }

  /// 获取服务商简称
  String _getProviderShortName(ApiProvider provider) {
    return switch (provider) {
      ApiProvider.aliyun => '阿里',
      ApiProvider.zhipu => '智谱',
      ApiProvider.xunfei => '讯飞',
      ApiProvider.tencent => '腾讯',
      ApiProvider.openai => 'OpenAI',
    };
  }

  /// 获取 Key 占位符
  String _getKeyPlaceholder(ApiProvider provider) {
    return switch (provider) {
      ApiProvider.aliyun => 'sk-xxxxxxxxxxxxxxxx',
      ApiProvider.zhipu => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      ApiProvider.xunfei => 'xxxxxxxx:xxxxxxxx',
      ApiProvider.tencent => 'xxxxxxxxxxxxxxxx',
      ApiProvider.openai => 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
    };
  }

  /// 获取状态文字
  String _getStatusText(ApiConfig? config) {
    if (config == null) return '未配置';
    if (config.isEnabled) return '已启用';
    if (config.isConfigured) return '已配置';
    return '未配置';
  }

  /// 获取状态颜色
  Color _getStatusColor(ApiConfig? config) {
    if (config == null) return AppColors.muted;
    if (config.isEnabled) return AppColors.accent;
    return AppColors.muted;
  }
}

/// 输入控制器封装类
class _InputControllers {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController keyController = TextEditingController();
  final TextEditingController modelController = TextEditingController();

  void dispose() {
    urlController.dispose();
    keyController.dispose();
    modelController.dispose();
  }
}