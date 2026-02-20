import 'package:flutter/material.dart';
import '../../core/utils/password_generator.dart';

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

  Color _getStrengthColor() {
    if (_strength < 40) return Colors.red;
    if (_strength < 70) return Colors.orange;
    if (_strength < 90) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getStrengthText() {
    if (_strength < 40) return '弱';
    if (_strength < 70) return '一般';
    if (_strength < 90) return '强';
    return '非常强';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('生成密码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 生成的密码显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _strength / 100,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation(_getStrengthColor()),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '强度: ${_getStrengthText()} ($_strength/100)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStrengthColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
              CheckboxListTile(
                title: const Text('大写字母 (A-Z)'),
                value: _includeUppercase,
                onChanged: (value) {
                  setState(() => _includeUppercase = value ?? true);
                  _generatePassword();
                },
              ),
              CheckboxListTile(
                title: const Text('小写字母 (a-z)'),
                value: _includeLowercase,
                onChanged: (value) {
                  setState(() => _includeLowercase = value ?? true);
                  _generatePassword();
                },
              ),
              CheckboxListTile(
                title: const Text('数字 (0-9)'),
                value: _includeNumbers,
                onChanged: (value) {
                  setState(() => _includeNumbers = value ?? true);
                  _generatePassword();
                },
              ),
              CheckboxListTile(
                title: const Text('特殊字符 (!@#...)'),
                value: _includeSymbols,
                onChanged: (value) {
                  setState(() => _includeSymbols = value ?? true);
                  _generatePassword();
                },
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
