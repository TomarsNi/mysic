import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/services/audio_player_service.dart';

/// 播放控制组件
/// 包含播放/暂停、上一首、下一首按钮
class PlayControls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool hasPlaylist;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final double iconSize;
  final double playButtonSize;

  const PlayControls({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.hasPlaylist,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    this.iconSize = 32,
    this.playButtonSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 上一首按钮
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          onPressed: hasPlaylist ? onPrevious : null,
          size: iconSize,
        ),

        const SizedBox(width: 24),

        // 播放/暂停按钮
        _PlayButton(
          isPlaying: isPlaying,
          isLoading: isLoading,
          onPressed: onPlayPause,
          size: playButtonSize,
        ),

        const SizedBox(width: 24),

        // 下一首按钮
        _ControlButton(
          icon: Icons.skip_next_rounded,
          onPressed: hasPlaylist ? onNext : null,
          size: iconSize,
        ),
      ],
    );
  }
}

/// 播放/暂停按钮
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;
  final double size;

  const _PlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: size * 0.5,
                    height: size * 0.5,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: size * 0.6,
                    color: AppColors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 控制按钮
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size * 1.5,
          height: size * 1.5,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: size,
            color: isEnabled ? AppColors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// 扩展控制组件
/// 包含随机播放、循环模式按钮
class ExtendedControls extends StatelessWidget {
  final bool isShuffleMode;
  final MysicLoopMode loopMode;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleLoop;

  const ExtendedControls({
    super.key,
    required this.isShuffleMode,
    required this.loopMode,
    required this.onToggleShuffle,
    required this.onToggleLoop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 随机播放按钮
        _ModeButton(
          icon: Icons.shuffle_rounded,
          isActive: isShuffleMode,
          onPressed: onToggleShuffle,
        ),

        const SizedBox(width: 32),

        // 循环模式按钮
        _ModeButton(
          icon: _getLoopIcon(),
          isActive: loopMode != MysicLoopMode.off,
          onPressed: onToggleLoop,
          badge: loopMode == MysicLoopMode.one ? '1' : null,
        ),
      ],
    );
  }

  IconData _getLoopIcon() {
    switch (loopMode) {
      case MysicLoopMode.off:
        return Icons.repeat_rounded;
      case MysicLoopMode.one:
        return Icons.repeat_one_rounded;
      case MysicLoopMode.all:
        return Icons.repeat_rounded;
    }
  }
}

/// 模式按钮
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final String? badge;

  const _ModeButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: isActive ? AppColors.accent : AppColors.muted,
              ),
              if (badge != null)
                Positioned(
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accent : AppColors.muted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
