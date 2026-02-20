import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 安全文本输入框
///
/// 密码输入框组件，带显示/隐藏切换功能
/// 支持密码强度指示器、复制按钮等安全相关功能
///
/// 参考文档: [保险库模块设计](wiki/03-模块设计/保险库模块.md) 第 7.1 节 - 代码实现映射
/// 参考文档: [安全架构](wiki/02-架构设计/安全架构.md) 第 3.3 节 - 剪贴板安全
class SecureTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool showStrengthIndicator;
  final bool showCopyButton;
  final int? passwordStrength;

  const SecureTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.showStrengthIndicator = false,
    this.showCopyButton = false,
    this.passwordStrength,
  });

  @override
  State<SecureTextField> createState() => _SecureTextFieldState();
}

class _SecureTextFieldState extends State<SecureTextField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Color _getStrengthColor(int strength) {
    if (strength < 40) return Colors.red;
    if (strength < 70) return Colors.orange;
    if (strength < 90) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getStrengthText(int strength) {
    if (strength < 40) return '弱';
    if (strength < 70) return '一般';
    if (strength < 90) return '强';
    return '非常强';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : const Icon(Icons.lock_outline),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showCopyButton && widget.controller?.text.isNotEmpty == true)
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () {
                      final text = widget.controller?.text ?? '';
                      if (text.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制到剪贴板'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    tooltip: '复制',
                  ),
                IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: _toggleVisibility,
                  tooltip: _obscureText ? '显示密码' : '隐藏密码',
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline.withAlpha(128)),
            ),
            filled: !widget.enabled,
            fillColor: widget.enabled ? null : colorScheme.surfaceContainerHighest.withAlpha(128),
          ),
          textInputAction: widget.textInputAction,
          obscureText: _obscureText,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: widget.enabled ? colorScheme.onSurface : colorScheme.onSurface.withAlpha(128),
            fontFamily: 'monospace',
            letterSpacing: _obscureText ? 2 : 0,
          ),
        ),
        if (widget.showStrengthIndicator && widget.passwordStrength != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (widget.passwordStrength! / 100).clamp(0.0, 1.0),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _getStrengthColor(widget.passwordStrength!),
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '强度: ${_getStrengthText(widget.passwordStrength!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getStrengthColor(widget.passwordStrength!),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
