import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/tools/clipboard_service.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/theme/vaultly_colors.dart';
import 'app_toast.dart';
import 'mono_text.dart';

/// 详情页字段行（原型 `.field-card .row`）
///
/// 行式布局：标签 12 muted + 值 16/500（敏感值遮罩、等宽渲染）+ 尾部操作
/// （眼睛 / 自定义 / 复制）。行高不小于 60，背景与分隔线由外层分组卡片负责。
class FieldRow extends StatefulWidget {
  final String label;
  final String value;

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

  /// 值下方的附加内容（如密码强度条）
  final Widget? footer;

  /// 是否显示复制按钮
  final bool copyable;

  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.isSensitive = false,
    this.mono = false,
    this.copyLabel,
    this.trailing,
    this.onTap,
    this.footer,
    this.copyable = true,
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

    final valueText = _showValue ? widget.value : '••••••••••••';
    final valueStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: _showValue ? 0 : 1.5,
    );

    return InkWell(
      onTap: widget.onTap ?? (widget.copyable ? _copy : null),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (widget.mono || widget.isSensitive)
                    MonoText(
                      valueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    )
                  else
                    Text(
                      valueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                  if (widget.footer != null) ...[
                    const SizedBox(height: 6),
                    widget.footer!,
                  ],
                ],
              ),
            ),
            if (widget.isSensitive)
              _TrailingButton(
                icon: _obscured
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                tooltip: _obscured ? '显示' : '隐藏',
                onTap: () => setState(() => _obscured = !_obscured),
              ),
            if (widget.trailing != null) widget.trailing!,
            if (widget.copyable)
              AnimatedSwitcher(
                duration: AppTokens.animFast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: _copied
                    ? const _TrailingButton(
                        key: ValueKey('copied'),
                        icon: Icons.check_circle_rounded,
                        tooltip: '已复制',
                        color: Color(0xFF059669),
                      )
                    : _TrailingButton(
                        key: const ValueKey('copy'),
                        icon: Icons.copy_rounded,
                        tooltip: '复制',
                        onTap: _copy,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 字段行尾部的小图标按钮（36x36，与行高对齐）
class _TrailingButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _TrailingButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: color ?? Theme.of(context).colorScheme.textMuted,
          ),
        ),
      ),
    );
  }
}
