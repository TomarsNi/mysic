import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/music_scanner.dart';

/// 扫描按钮组件
/// 用于触发本地音乐扫描，显示扫描进度和结果
class ScanButton extends StatefulWidget {
  /// 音乐扫描服务实例
  final MusicScanner scanner;

  /// 扫描完成回调
  final void Function(ScanResult result)? onScanComplete;

  /// 扫描开始回调
  final VoidCallback? onScanStart;

  /// 扫描错误回调
  final void Function(String error)? onScanError;

  const ScanButton({
    super.key,
    required this.scanner,
    this.onScanComplete,
    this.onScanStart,
    this.onScanError,
  });

  @override
  State<ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<ScanButton> with SingleTickerProviderStateMixin {
  ScanState _scanState = ScanState.idle;
  double _progress = 0.0;
  int _foundCount = 0;
  ScanResult? _lastResult;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 监听扫描状态
    widget.scanner.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _scanState = state;
        });

        if (state == ScanState.scanning || state == ScanState.saving) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });

    // 监听扫描进度
    widget.scanner.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress.progress;
          _foundCount = progress.songsFound;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _progress = 0.0;
      _foundCount = 0;
      _lastResult = null;
    });

    widget.onScanStart?.call();

    final result = await widget.scanner.scanMusic();

    if (mounted) {
      setState(() {
        _lastResult = result;
      });

      if (result.isSuccess) {
        widget.onScanComplete?.call(result);
      } else if (result.errorMessage != null) {
        widget.onScanError?.call(result.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 扫描按钮
        _buildScanButton(),

        // 进度指示器
        if (_scanState == ScanState.scanning || _scanState == ScanState.saving)
          _buildProgressIndicator(),

        // 扫描结果
        if (_lastResult != null) _buildResultCard(),
      ],
    );
  }

  Widget _buildScanButton() {
    final isScanning = _scanState == ScanState.scanning || _scanState == ScanState.saving;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isScanning ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: isScanning ? null : AppColors.accentGradient,
              color: isScanning ? AppColors.card : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isScanning
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isScanning ? null : _startScan,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 图标
                      isScanning
                          ? _buildScanningIcon()
                          : const Icon(
                              Icons.folder_open_rounded,
                              color: AppColors.white,
                              size: 24,
                            ),

                      const SizedBox(width: 12),

                      // 文字
                      Text(
                        _getButtonText(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanningIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
        backgroundColor: AppColors.muted.withValues(alpha: 0.3),
      ),
    );
  }

  String _getButtonText() {
    switch (_scanState) {
      case ScanState.idle:
        return '扫描本地音乐';
      case ScanState.scanning:
        return '正在扫描...';
      case ScanState.saving:
        return '正在保存 ($_foundCount 首)';
      case ScanState.completed:
        return '扫描完成';
      case ScanState.error:
        return '扫描失败，点击重试';
    }
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 8),

          // 进度文字
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _scanState == ScanState.scanning ? '扫描中...' : '保存中...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult!;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isSuccess
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.muted.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                result.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: result.isSuccess ? AppColors.accent : AppColors.muted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.isSuccess ? '扫描完成' : '扫描失败',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: result.isSuccess ? AppColors.accent : AppColors.muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 详情
          if (result.isSuccess) ...[
            _buildResultRow('发现歌曲', '${result.totalFound} 首'),
            const SizedBox(height: 8),
            _buildResultRow('新增歌曲', '${result.newAdded} 首'),
            const SizedBox(height: 8),
            _buildResultRow('已存在', '${result.duplicates} 首'),
            const SizedBox(height: 8),
            _buildResultRow('耗时', _formatDuration(result.scanDuration)),
          ] else ...[
            Text(
              result.errorMessage ?? '未知错误',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} 秒';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes 分 $seconds 秒';
  }
}

/// 扫描对话框
/// 显示扫描进度和结果，扫描完成后自动关闭
class ScanDialog extends StatefulWidget {
  final MusicScanner scanner;

  const ScanDialog({super.key, required this.scanner});

  /// 显示扫描对话框
  static Future<ScanResult?> show(BuildContext context, {required MusicScanner scanner}) {
    return showDialog<ScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScanDialog(scanner: scanner),
    );
  }

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  ScanState _scanState = ScanState.idle;
  double _progress = 0.0;
  int _foundCount = 0;
  ScanResult? _result;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    widget.scanner.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _scanState = state;
        });

        // 扫描完成后延迟关闭
        if (state == ScanState.completed || state == ScanState.error) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop(_result);
            }
          });
        }
      }
    });

    widget.scanner.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress.progress;
          _foundCount = progress.songsFound;
        });
      }
    });

    _result = await widget.scanner.scanMusic();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        _getTitle(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度指示器
          if (_scanState == ScanState.scanning || _scanState == ScanState.saving) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.card,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '已发现 $_foundCount 首歌曲',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ],

          // 结果显示
          if (_result != null) ...[
            Icon(
              _result!.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: _result!.isSuccess ? AppColors.accent : AppColors.muted,
              size: 48,
            ),
            const SizedBox(height: 16),
            if (_result!.isSuccess) ...[
              Text(
                '发现 ${_result!.totalFound} 首歌曲',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '新增 ${_result!.newAdded} 首，已存在 ${_result!.duplicates} 首',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ] else ...[
              Text(
                _result!.errorMessage ?? '扫描失败',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_scanState) {
      case ScanState.idle:
        return '准备扫描...';
      case ScanState.scanning:
        return '正在扫描...';
      case ScanState.saving:
        return '正在保存...';
      case ScanState.completed:
        return '扫描完成';
      case ScanState.error:
        return '扫描失败';
    }
  }
}
