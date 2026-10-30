import 'package:flutter/material.dart';
import '../password_generator.dart';
import '../password_policy.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../../features/tools/clipboard_service.dart';

/// 密码生成器面板（原型 tools.html `.gen-card`）
///
/// 结果展示框（bg + line-strong 描边 + 等宽大号）→ 强度条 → 长度滑杆
/// → 字符组成开关（大写/小写/数字/符号/易读），开关行之间 1px 分隔。
class PasswordGeneratorPanel extends StatefulWidget {
  const PasswordGeneratorPanel({super.key});

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
        _generatedPassword = PasswordGenerator.generateReadable(
          length: _length,
        );
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
    await ClipboardService().copySensitive(
      _generatedPassword,
      label: 'generator',
    );
    if (mounted) AppToast.show(context, '密码已复制（30 秒后自动清除）');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strength = PasswordGenerator.calculateStrength(_generatedPassword);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 结果展示框
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: colorScheme.bg,
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
            border: Border.all(color: colorScheme.hairlineStrong),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _generatedPassword,
                  style: TextStyle(
                    fontFamily: AppTokens.monoFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    letterSpacing: 0.6,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              _GenIconButton(
                icon: Icons.refresh_rounded,
                tooltip: '重新生成',
                onTap: _generate,
              ),
              _GenIconButton(
                icon: Icons.content_copy_rounded,
                tooltip: '复制密码',
                onTap: _copy,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),

        // 强度条
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (strength / 100).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: colorScheme.surfaceTrack,
                  color: _strengthColor(strength, colorScheme),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              PasswordPolicy.getStrengthLabel(strength),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _strengthColor(strength, colorScheme),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),

        // 长度
        Row(
          children: [
            Text(
              '长度',
              style: TextStyle(fontSize: 14, color: colorScheme.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Slider(
                value: _length.toDouble(),
                min: 8,
                max: 64,
                divisions: 56,
                label: _length.toString(),
                onChanged: (value) {
                  setState(() => _length = value.round());
                  _generate();
                },
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 36,
              child: Text(
                '$_length',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppTokens.monoFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceS),

        // 字符组成
        _ToggleRow(
          title: '大写字母 (A–Z)',
          value: _includeUppercase,
          onChanged: (v) {
            if (!v && !_canToggleAfter('upper')) return;
            setState(() => _includeUppercase = v);
            _generate();
          },
        ),
        _ToggleRow(
          title: '小写字母 (a–z)',
          value: _includeLowercase,
          onChanged: (v) {
            if (!v && !_canToggleAfter('lower')) return;
            setState(() => _includeLowercase = v);
            _generate();
          },
        ),
        _ToggleRow(
          title: '数字 (0–9)',
          value: _includeNumbers,
          onChanged: (v) {
            if (!v && !_canToggleAfter('number')) return;
            setState(() => _includeNumbers = v);
            _generate();
          },
        ),
        _ToggleRow(
          title: '符号 (!@#…)',
          value: _includeSymbols,
          onChanged: (v) {
            if (!v && !_canToggleAfter('symbol')) return;
            setState(() => _includeSymbols = v);
            _generate();
          },
        ),
        _ToggleRow(
          title: '易读模式',
          subtitle: '排除 0/O、1/l 等易混淆字符',
          value: _readable,
          onChanged: (v) {
            setState(() => _readable = v);
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

  Color _strengthColor(int strength, ColorScheme colorScheme) {
    if (strength < 40) return colorScheme.error;
    if (strength < 70) {
      return colorScheme.isDark
          ? AppTokens.warningDark
          : AppTokens.warningLight;
    }
    return colorScheme.accent;
  }
}

/// 生成器小图标按钮（36x36）
class _GenIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GenIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 19, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

/// 开关行（原型 `.gen-row`，行间 1px 分隔）
class _ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: textTheme.bodyMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
