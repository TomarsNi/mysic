import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// 关于页面
/// 显示应用信息、版本、开发者信息、支持作者等
class AboutPage extends StatelessWidget {
  /// 应用名称
  final String appName;

  /// 应用版本
  final String appVersion;

  /// 构建号
  final String buildNumber;

  /// 开发者名称
  final String developerName;

  /// 开发者网站
  final String? developerWebsite;

  /// 开发者邮箱
  final String? developerEmail;

  /// 许可证链接
  final String? licenseUrl;

  /// 隐私政策链接
  final String? privacyPolicyUrl;

  /// 服务条款链接
  final String? termsOfServiceUrl;

  const AboutPage({
    super.key,
    this.appName = 'Mysic',
    this.appVersion = '1.0.0',
    this.buildNumber = '1',
    this.developerName = 'NBB',
    this.developerWebsite,
    this.developerEmail,
    this.licenseUrl,
    this.privacyPolicyUrl,
    this.termsOfServiceUrl,
  });

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
      title: const Text(
        '关于',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // 应用图标和名称
            _buildAppHeader(context),

            const SizedBox(height: 32),

            // 应用描述
            _buildAppDescription(context),

            const SizedBox(height: 24),

            // 版本信息卡片
            _buildVersionCard(context),

            const SizedBox(height: 24),

            // 开发者信息
            _buildDeveloperSection(context),

            const SizedBox(height: 24),

            // 链接区域
            _buildLinksSection(context),

            const SizedBox(height: 24),

            // 支持作者
            _buildSupportSection(context),

            const SizedBox(height: 32),

            // 版权信息
            _buildCopyright(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context) {
    return Column(
      children: [
        // 应用图标
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: AppColors.white,
            size: 48,
          ),
        ),

        const SizedBox(height: 20),

        // 应用名称
        Text(
          appName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),

        const SizedBox(height: 8),

        // 应用标语
        const Text(
          '本地音乐播放器',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildAppDescription(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Mysic 是一款简洁优雅的本地音乐播放器，支持多种音频格式，'
        '提供歌单管理、歌词显示、后台播放等功能。'
        '专注于为用户带来纯粹的音乐聆听体验。',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.muted,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVersionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 版本号
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: '版本',
            value: 'v$appVersion ($buildNumber)',
            onTap: () => _copyVersion(context),
          ),

          const Divider(color: AppColors.surface, height: 24),

          // 技术栈
          const _InfoRow(
            icon: Icons.code_rounded,
            label: '技术栈',
            value: 'Flutter',
          ),

          const Divider(color: AppColors.surface, height: 24),

          // 平台
          const _InfoRow(
            icon: Icons.devices_rounded,
            label: '支持平台',
            value: 'Android / iOS / Windows',
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '开发者',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: '开发者',
                value: developerName,
              ),

              if (developerWebsite != null) ...[
                const Divider(color: AppColors.surface, height: 24),
                _InfoRow(
                  icon: Icons.language_rounded,
                  label: '网站',
                  value: developerWebsite!,
                  isLink: true,
                  onTap: () => _launchUrl(developerWebsite!),
                ),
              ],

              if (developerEmail != null) ...[
                const Divider(color: AppColors.surface, height: 24),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: '邮箱',
                  value: developerEmail!,
                  isLink: true,
                  onTap: () => _sendEmail(developerEmail!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinksSection(BuildContext context) {
    // 如果没有任何链接，不显示此区域
    if (licenseUrl == null && privacyPolicyUrl == null && termsOfServiceUrl == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '法律信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (licenseUrl != null)
                _LinkTile(
                  icon: Icons.description_outlined,
                  title: '开源许可证',
                  onTap: () => _launchUrl(licenseUrl!),
                ),

              if (licenseUrl != null && privacyPolicyUrl != null)
                const Divider(color: AppColors.surface, height: 1, indent: 56),

              if (privacyPolicyUrl != null)
                _LinkTile(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  onTap: () => _launchUrl(privacyPolicyUrl!),
                ),

              if (privacyPolicyUrl != null && termsOfServiceUrl != null)
                const Divider(color: AppColors.surface, height: 1, indent: 56),

              if (termsOfServiceUrl != null)
                _LinkTile(
                  icon: Icons.article_outlined,
                  title: '服务条款',
                  onTap: () => _launchUrl(termsOfServiceUrl!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // 图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),

          const SizedBox(height: 16),

          // 标题
          const Text(
            '支持作者',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),

          const SizedBox(height: 8),

          // 描述
          const Text(
            '如果您喜欢这款应用，欢迎支持开发者继续改进产品',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // 支持按钮
          Row(
            children: [
              Expanded(
                child: _SupportButton(
                  icon: Icons.star_rounded,
                  label: '给个 Star',
                  onTap: () => _showStarDialog(context),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _SupportButton(
                  icon: Icons.coffee_rounded,
                  label: '请喝咖啡',
                  onTap: () => _showDonateDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCopyright(BuildContext context) {
    final year = DateTime.now().year;

    return Column(
      children: [
        Text(
          'Made with ❤️ by $developerName',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '© $year $developerName. All rights reserved.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  void _copyVersion(BuildContext context) {
    Clipboard.setData(ClipboardData(text: 'v$appVersion ($buildNumber)'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('版本信息已复制'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _launchUrl(String url) {
    // TODO: 使用 url_launcher 打开链接
    // 目前仅打印日志
    debugPrint('Launch URL: $url');
  }

  void _sendEmail(String email) {
    // TODO: 使用 url_launcher 打开邮件客户端
    // 目前仅打印日志
    debugPrint('Send email to: $email');
  }

  void _showStarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.star_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('感谢支持'),
          ],
        ),
        content: const Text(
          '如果您在 GitHub 上给项目点个 Star，将是对开发者最大的鼓励！',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 打开 GitHub 页面
            },
            child: const Text(
              '前往 GitHub',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.coffee_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('请喝咖啡'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '感谢您的支持！',
              style: TextStyle(color: AppColors.muted),
            ),
            SizedBox(height: 16),
            Text(
              '支付宝 / 微信收款码',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            // TODO: 添加收款码图片
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 信息行组件
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.muted,
            ),

            const SizedBox(width: 12),

            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),

            const Spacer(),

            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isLink ? AppColors.accent : AppColors.white,
                fontWeight: isLink ? FontWeight.w500 : FontWeight.normal,
              ),
            ),

            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.muted.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 链接列表项组件
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.muted,
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.white,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.muted,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// 支持按钮组件
class _SupportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SupportButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppColors.accent,
                size: 24,
              ),

              const SizedBox(height: 6),

              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
