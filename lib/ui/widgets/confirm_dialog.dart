import 'package:flutter/material.dart';

/// 确认对话框
///
/// 统一的确认对话框组件，支持危险操作、信息提示等场景
///
/// 参考文档: [保险库模块设计](wiki/03-模块设计/保险库模块.md) 第 7.1 节 - 代码实现映射
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final Color? iconColor;
  final bool isDangerous;
  final bool barrierDismissible;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.icon,
    this.iconColor,
    this.isDangerous = false,
    this.barrierDismissible = true,
  });

  /// 显示删除确认对话框
  static Future<bool> showDelete({
    required BuildContext context,
    required String itemName,
    String? content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '删除确认',
        content: content ?? '确定要删除 "$itemName" 吗？此操作不可恢复。',
        confirmLabel: '删除',
        cancelLabel: '取消',
        icon: Icons.delete_outline,
        iconColor: Colors.red,
        isDangerous: true,
      ),
    );
    return result ?? false;
  }

  /// 显示退出确认对话框
  static Future<bool> showExit({
    required BuildContext context,
    String? content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '退出确认',
        content: content ?? '确定要退出吗？未保存的更改将丢失。',
        confirmLabel: '退出',
        cancelLabel: '继续编辑',
        icon: Icons.exit_to_app_outlined,
        isDangerous: false,
      ),
    );
    return result ?? false;
  }

  /// 显示丢弃更改确认对话框
  static Future<bool> showDiscard({
    required BuildContext context,
    String? content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '丢弃更改',
        content: content ?? '确定要丢弃所有更改吗？',
        confirmLabel: '丢弃',
        cancelLabel: '继续编辑',
        icon: Icons.delete_forever_outlined,
        iconColor: Colors.orange,
        isDangerous: true,
      ),
    );
    return result ?? false;
  }

  /// 显示清除数据确认对话框
  static Future<bool> showClearData({
    required BuildContext context,
    String? content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '清除数据',
        content: content ?? '确定要清除所有本地数据吗？此操作不可恢复。',
        confirmLabel: '清除',
        cancelLabel: '取消',
        icon: Icons.cleaning_services_outlined,
        iconColor: Colors.red,
        isDangerous: true,
      ),
    );
    return result ?? false;
  }

  /// 显示通用确认对话框
  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    IconData? icon,
    Color? iconColor,
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        iconColor: iconColor,
        isDangerous: isDangerous,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveIconColor = iconColor ??
        (isDangerous ? colorScheme.error : colorScheme.primary);

    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              color: effectiveIconColor,
              size: 32,
            )
          : null,
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      content: contentWidget ??
          (content != null
              ? Text(
                  content!,
                  textAlign: TextAlign.center,
                )
              : null),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isDangerous
                  ? FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      child: Text(confirmLabel),
                    )
                  : FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmLabel),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 输入确认对话框
///
/// 需要用户输入内容确认的对话框
class InputConfirmDialog extends StatefulWidget {
  final String title;
  final String? hintText;
  final String? initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  const InputConfirmDialog({
    super.key,
    required this.title,
    this.hintText,
    this.initialValue,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  /// 显示输入确认对话框
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? hintText,
    String? initialValue,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => InputConfirmDialog(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }

  @override
  State<InputConfirmDialog> createState() => _InputConfirmDialogState();
}

class _InputConfirmDialogState extends State<InputConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          validator: widget.validator,
          autofocus: true,
          onFieldSubmitted: (value) {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
