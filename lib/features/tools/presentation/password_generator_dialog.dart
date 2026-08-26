import 'package:flutter/material.dart';
import '../password_generator.dart';
import '../../../ui/theme/tokens.dart';

/// 密码生成器对话框
///
/// 提供可视化的密码生成选项
class PasswordGeneratorDialog extends StatefulWidget {
  final String? initialPassword;

  const PasswordGeneratorDialog({
    super.key,
    this.initialPassword,
  });

  @override
  State<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  bool _readable = false;

  String _generatedPassword = '';
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _generatedPassword = widget.initialPassword ?? '';
    if (_generatedPassword.isNotEmpty) {
      _strength = PasswordGenerator.calculateStrength(_generatedPassword);
    } else {
      _generatePassword();
    }
  }

  void _generatePassword() {
    setState(() {
      if (_readable) {
        _generatedPassword = PasswordGenerator.generateReadable(length: _length);
      } else {
        _generatedPassword = PasswordGenerator.generate(
          length: _length,
          includeUppercase: _includeUppercase,
          includeLowercase: _includeLowercase,
          includeNumbers: _includeNumbers,
          includeSymbols: _includeSymbols,
        );
      }
      _strength = PasswordGenerator.calculateStrength(_generatedPassword);
    });
  }

  /// 根据强度与主题亮度返回可读的颜色（深色模式使用浅色变体保证对比度）
  Color _getStrengthColor(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    if (_strength < 40) return colorScheme.error;
    if (_strength < 70) return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
    if (_strength < 90) return isDark ? Colors.amber.shade200 : Colors.amber.shade800;
    return isDark ? Colors.green.shade300 : Colors.green.shade700;
  }

  String _getStrengthText() {
    if (_strength < 40) return '弱';
    if (_strength < 70) return '一般';
    if (_strength < 90) return '强';
    return '非常强';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strengthColor = _getStrengthColor(colorScheme);

    return AlertDialog(
      title: const Text('生成密码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 生成的密码显示
            Container(
              padding: const EdgeInsets.all(AppTokens.spaceM),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTokens.radiusM),
              ),
              child: Column(
                children: [
                  SelectableText(
                    _generatedPassword,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  LinearProgressIndicator(
                    value: _strength / 100,
                    backgroundColor: colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation(strengthColor),
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    '强度: ${_getStrengthText()} ($_strength/100)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: strengthColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceL),

            // 密码长度
            Row(
              children: [
                const Text('长度:'),
                Expanded(
                  child: Slider(
                    value: _length.toDouble(),
                    min: 8,
                    max: 32,
                    divisions: 24,
                    label: _length.toString(),
                    onChanged: (value) {
                      setState(() => _length = value.round());
                      _generatePassword();
                    },
                  ),
                ),
                Text('$_length'),
              ],
            ),

            // 易读模式
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('易读模式'),
              subtitle: const Text('排除容易混淆的字符'),
              value: _readable,
              onChanged: (value) {
                setState(() => _readable = value);
                _generatePassword();
              },
            ),

            // 字符类型选项
            if (!_readable) ...[
              const SizedBox(height: AppTokens.spaceS),
              Wrap(
                spacing: AppTokens.spaceS,
                runSpacing: AppTokens.spaceS,
                children: [
                  FilterChip(
                    label: const Text('大写 A-Z'),
                    selected: _includeUppercase,
                    onSelected: (value) {
                      setState(() => _includeUppercase = value || _includeLowercase || _includeNumbers || _includeSymbols);
                      _generatePassword();
                    },
                  ),
                  FilterChip(
                    label: const Text('小写 a-z'),
                    selected: _includeLowercase,
                    onSelected: (value) {
                      setState(() => _includeLowercase = value || _includeUppercase || _includeNumbers || _includeSymbols);
                      _generatePassword();
                    },
                  ),
                  FilterChip(
                    label: const Text('数字 0-9'),
                    selected: _includeNumbers,
                    onSelected: (value) {
                      setState(() => _includeNumbers = value || _includeUppercase || _includeLowercase || _includeSymbols);
                      _generatePassword();
                    },
                  ),
                  FilterChip(
                    label: const Text('符号 !@#'),
                    selected: _includeSymbols,
                    onSelected: (value) {
                      setState(() => _includeSymbols = value || _includeUppercase || _includeLowercase || _includeNumbers);
                      _generatePassword();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _generatePassword,
          icon: const Icon(Icons.refresh),
          label: const Text('重新生成'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _generatedPassword),
          child: const Text('使用'),
        ),
      ],
    );
  }
}
