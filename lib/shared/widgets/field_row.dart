import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/tools/clipboard_service.dart';
import '../../ui/theme/tokens.dart';
import 'app_toast.dart';
import 'mono_text.dart';

/// 详情页字段行
///
/// `标签 + 值（敏感值遮罩）+ 眼睛切换 + 复制按钮`，
/// 点按整行复制主字段并给予 ✓ 反馈 + 触觉反馈。
/// 密码/卡号/CVV/证件号等机密值使用等宽字体。
class FieldRow extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;

  /// 是否敏感（默认遮罩 + 眼睛切换 + 复制后自动清除剪贴板）
  final bool isSensitive;

  /// 是否用等宽字体渲染（密码/验证码/卡号默认 true）
  final bool mono;

  /// 值的语义：用于复制提示文案（如「密码 已复制」）
  final String? copyLabel;

  /// 自定义尾部（如 URL 的打开按钮）
  final Widget? trailing;

  /// 点按行为：null = 复制值
  final VoidCallback? onTap;

  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isSensitive = false,
    this.mono = false,
    this.copyLabel,
    this.trailing,
    this.onTap,
  });

  @override
  State<FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<FieldRow> {
  bool _obscured = true;
  bool _copied = false;

  bool get _showValue => !widget.isSensitive || !_obscured;

  Future<void> _copy() async {
    if (widget.isSensitive) {
      await ClipboardService().copySensitive(widget.value, label: widget.label);
    } else {
      await ClipboardService.copy(widget.value, clearAfterSeconds: null);
    }
    HapticFeedback.selectionClick();
    if (!mounted) return;
    AppToast.show(context, '${widget.copyLabel ?? widget.label} 已复制');
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final valueText = _showValue
        ? widget.value
        : '••••••••';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(76),
        ),
      ),
      child: InkWell(
        onTap: widget.onTap ?? _copy,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceL,
            vertical: AppTokens.spaceM,
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppTokens.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (widget.mono || widget.isSensitive)
                      MonoText(
                        valueText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: _showValue ? 0.5 : 2,
                        ),
                      )
                    else
                      Text(
                        valueText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isSensitive)
                IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                  tooltip: _obscured ? '显示' : '隐藏',
                ),
              if (widget.trailing != null) widget.trailing!,
              AnimatedSwitcher(
                duration: AppTokens.animFast,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: _copied
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('copied'),
                        size: 20,
                        color: Color(0xFF059669),
                      )
                    : IconButton(
                        key: const ValueKey('copy'),
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: _copy,
                        tooltip: '复制',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
