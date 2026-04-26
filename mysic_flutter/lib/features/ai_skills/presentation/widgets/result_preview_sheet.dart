// lib/features/ai_skills/presentation/widgets/result_preview_sheet.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/ai_skills/core/ai_skill.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/ai_skills/presentation/providers/ai_skills_provider.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

/// 结果预览界面
/// 显示 AI 分析结果，用户可确认或取消
class ResultPreviewSheet extends StatelessWidget {
  /// 当前执行的 Skill
  final AiSkill skill;

  /// 执行状态
  final SkillExecutionStatus status;

  /// 执行结果
  final SkillResult? result;

  /// 原始歌曲信息
  final Song? song;

  /// 确认回调
  final VoidCallback? onConfirm;

  /// 取消回调
  final VoidCallback? onCancel;

  /// 重试回调
  final VoidCallback? onRetry;

  const ResultPreviewSheet({
    super.key,
    required this.skill,
    required this.status,
    this.result,
    this.song,
    this.onConfirm,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 根据状态显示不同内容
          switch (status) {
            SkillExecutionStatus.idle => const SizedBox.shrink(),
            SkillExecutionStatus.loading => _buildLoadingState(),
            SkillExecutionStatus.success => _buildSuccessState(),
            SkillExecutionStatus.noChange => _buildNoChangeState(),
            SkillExecutionStatus.failure => _buildFailureState(),
          },
        ],
      ),
    );
  }

  /// 加载中状态
  Widget _buildLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(
          color: AppColors.accent,
        ),
        const SizedBox(height: 24),
        Text(
          '正在${skill.displayName}...',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// 成功状态
  Widget _buildSuccessState() {
    if (result is! SkillSuccess) return const SizedBox.shrink();

    final data = (result as SkillSuccess).data;

    // 根据 Skill 类型显示不同内容
    if (skill.id == 'song_recognition') {
      return _buildRecognitionResult(data);
    } else if (skill.id == 'lyrics_search') {
      return _buildLyricsResult(data);
    }

    return const SizedBox.shrink();
  }

  /// 歌曲识别结果
  Widget _buildRecognitionResult(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '识别结果',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // 歌曲名称
        _buildComparisonRow(
          label: '歌曲名称',
          oldValue: song?.title ?? '未知',
          newValue: data['title'] as String? ?? '',
        ),
        const SizedBox(height: 12),

        // 艺术家
        _buildComparisonRow(
          label: '艺术家',
          oldValue: song?.artist ?? '未知',
          newValue: data['artist'] as String? ?? '',
        ),
        const SizedBox(height: 12),

        // 专辑
        _buildComparisonRow(
          label: '专辑',
          oldValue: song?.album ?? '未知',
          newValue: data['album'] as String? ?? '',
        ),
        const SizedBox(height: 16),

        // 信息来源
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.muted,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '信息来源：${data['source'] == 'web_search' ? '联网搜索' : '模型知识'}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 操作按钮
        _buildActionButtons(),
      ],
    );
  }

  /// 歌词搜索结果
  Widget _buildLyricsResult(Map<String, dynamic> data) {
    final lyrics = data['lyrics'] as String? ?? '';
    final lines = lyrics.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '歌词搜索结果',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // 匹配信息
        if (data['matchedSong'] != null)
          Text(
            '匹配歌曲：${data['matchedSong']['title']} - ${data['matchedSong']['artist']}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 12),

        // 歌词预览 - 可滚动
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            line,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 操作按钮
        _buildActionButtons(confirmText: '应用歌词'),
      ],
    );
  }

  /// 对比行
  Widget _buildComparisonRow({
    required String label,
    required String oldValue,
    required String newValue,
  }) {
    final hasChange = oldValue != newValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 原值
              Row(
                children: [
                  Expanded(
                    child: Text(
                      oldValue,
                      style: TextStyle(
                        color: hasChange
                            ? AppColors.muted
                            : AppColors.white,
                        fontSize: 14,
                        decoration: hasChange
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (hasChange)
                    const Icon(
                      Icons.close_rounded,
                      color: AppColors.muted,
                      size: 16,
                    ),
                ],
              ),
              // 新值
              if (hasChange) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        newValue,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 无变化状态
  Widget _buildNoChangeState() {
    final message =
        result is SkillNoChange ? (result as SkillNoChange).message : '信息已正确';

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.accent,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '信息正确',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('关闭'),
          ),
        ),
      ],
    );
  }

  /// 失败状态
  Widget _buildFailureState() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '处理失败',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result is SkillFailure
              ? (result as SkillFailure).message
              : '未知错误',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('重试'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButtons({String confirmText = '确认更新'}) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(confirmText),
          ),
        ),
      ],
    );
  }
}
