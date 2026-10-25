import 'package:flutter/material.dart';
import '../password_generator.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/mono_text.dart';
import '../../../ui/theme/tokens.dart';
import '../../../features/tools/clipboard_service.dart';

/// 密码生成器面板（页面内嵌组件）
///
/// 工具页主体；与 [PasswordGeneratorDialog] 复用同一生成核心，
/// 此处为页面化布局：大号等宽结果 + 强度条 + 参数控件。
class PasswordGeneratorPanel extends StatefulWidget {  const PasswordGeneratorPanel({super.key});

  @override
  State<PasswordGeneratorPanel> createState() => _PasswordGeneratorPanelState();
}

class _PasswordGeneratorPanelState extends State<PasswordGeneratorPanel> {
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  bool _readable = false;

  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
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
    });
  }

  Future<void> _copy() async {
    await ClipboardService()
        .copySensitive(_generatedPassword, label: 'generator');
    if (mounted) AppToast.show(context, '密码已复制（30 秒后自动清除）');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final strength = PasswordGenerator.calculateStrength(_generatedPassword);
    final (strengthColor, strengthLabel) = _strengthVisual(strength, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
              ),
              child: Icon(Icons.password_rounded,
                  size: 20, color: colorScheme.primary),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Text('密码生成器', style: textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),

        // 结果展示
        Container(
          padding: const EdgeInsets.all(AppTokens.spaceXL),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppTokens.radiusL),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(76),
            ),
          ),
          child: Column(
            children: [
              MonoText(
                _generatedPassword,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppTokens.spaceL),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusS),
                      child: LinearProgressIndicator(
                        value: strength / 100,
                        minHeight: 5,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(strengthColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceM),
                  Text(
                    strengthLabel,
                    style: textTheme.labelMedium
                        ?.copyWith(color: strengthColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceM),

        // 复制 / 重新生成
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新生成'),
              ),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('复制密码'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceXL),

        // 参数区
        _buildSectionLabel('长度 · $_length'),
        Slider(
          value: _length.toDouble(),
          min: 8,
          max: 32,
          divisions: 24,
          label: _length.toString(),
          onChanged: (value) {
            setState(() => _length = value.round());
            _generate();
          },
        ),
        const SizedBox(height: AppTokens.spaceM),

        _buildSectionLabel('字符组成'),
        if (_readable)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceS),
            child: Text(
              '易读模式已排除容易混淆的字符',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceS),
            child: Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                _buildCharChip('大写 A-Z', _includeUppercase, (v) {
                  if (!v && !_canToggleAfter('upper')) return;
                  setState(() => _includeUppercase = v);
                  _generate();
                }),
                _buildCharChip('小写 a-z', _includeLowercase, (v) {
                  if (!v && !_canToggleAfter('lower')) return;
                  setState(() => _includeLowercase = v);
                  _generate();
                }),
                _buildCharChip('数字 0-9', _includeNumbers, (v) {
                  if (!v && !_canToggleAfter('number')) return;
                  setState(() => _includeNumbers = v);
                  _generate();
                }),
                _buildCharChip('符号 !@#', _includeSymbols, (v) {
                  if (!v && !_canToggleAfter('symbol')) return;
                  setState(() => _includeSymbols = v);
                  _generate();
                }),
              ],
            ),
          ),
        const SizedBox(height: AppTokens.spaceM),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('易读模式'),
          subtitle: const Text('排除容易混淆的字符（0/O、1/l/I）'),
          value: _readable,
          onChanged: (value) {
            setState(() => _readable = value);
            _generate();
          },
        ),
      ],
    );
  }

  /// 关闭某类字符是否会导致全部关闭
  bool _canToggleAfter(String which) {
    var upper = _includeUppercase;
    var lower = _includeLowercase;
    var number = _includeNumbers;
    var symbol = _includeSymbols;
    switch (which) {
      case 'upper':
        upper = false;
      case 'lower':
        lower = false;
      case 'number':
        number = false;
      case 'symbol':
        symbol = false;
    }
    return upper || lower || number || symbol;
  }

  Widget _buildSectionLabel(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildCharChip(String label, bool selected, ValueChanged<bool> onSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
    );
  }

  (Color, String) _strengthVisual(int strength, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    if (strength < 40) {
      return (colorScheme.error, '弱');
    }
    if (strength < 70) {
      return (
        isDark ? const Color(0xFFFDBA74) : const Color(0xFFEA580C),
        '一般'
      );
    }
    if (strength < 90) {
      return (
        isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        '强'
      );
    }
    return (
      isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
      '非常强'
    );
  }
}
