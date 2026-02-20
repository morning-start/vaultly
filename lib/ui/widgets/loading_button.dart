import 'package:flutter/material.dart';

/// 加载按钮
///
/// 带加载状态的按钮组件，在异步操作时显示加载指示器
///
/// 参考文档: [保险库模块设计](wiki/03-模块设计/保险库模块.md) 第 7.1 节 - 代码实现映射
class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final ButtonType type;
  final Size? minimumSize;
  final EdgeInsetsGeometry? padding;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.type = ButtonType.elevated,
    this.minimumSize,
    this.padding,
  });

  /// 创建主要按钮（ElevatedButton）
  const LoadingButton.elevated({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.minimumSize,
    this.padding,
  }) : type = ButtonType.elevated;

  /// 创建次要按钮（FilledButton）
  const LoadingButton.filled({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.minimumSize,
    this.padding,
  }) : type = ButtonType.filled;

  /// 创建轮廓按钮（OutlinedButton）
  const LoadingButton.outlined({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.minimumSize,
    this.padding,
  }) : type = ButtonType.outlined;

  /// 创建文本按钮（TextButton）
  const LoadingButton.text({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.minimumSize,
    this.padding,
  }) : type = ButtonType.text;

  Widget _buildChild(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            type == ButtonType.elevated || type == ButtonType.filled
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (isLoading || !enabled) ? null : onPressed;
    final effectiveMinimumSize = minimumSize ?? const Size(88, 44);
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    switch (type) {
      case ButtonType.elevated:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: effectiveMinimumSize,
            padding: effectivePadding,
          ),
          child: _buildChild(context),
        );
      case ButtonType.filled:
        return FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: effectiveMinimumSize,
            padding: effectivePadding,
          ),
          child: _buildChild(context),
        );
      case ButtonType.outlined:
        return OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: effectiveMinimumSize,
            padding: effectivePadding,
          ),
          child: _buildChild(context),
        );
      case ButtonType.text:
        return TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            minimumSize: effectiveMinimumSize,
            padding: effectivePadding,
          ),
          child: _buildChild(context),
        );
    }
  }
}

/// 按钮类型枚举
enum ButtonType {
  elevated,
  filled,
  outlined,
  text,
}
