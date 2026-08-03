import 'package:flutter/material.dart';
import '../../core/utils/password_policy.dart';
import '../theme/tokens.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final int strength;
  final double? height;
  final bool showLabel;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
    this.height = 4,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (strength == 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final color = _getStrengthColor(strength, colorScheme);
    final label = PasswordPolicy.getStrengthLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusS),
          child: LinearProgressIndicator(
            value: strength / 100,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: height ?? 4,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            '密码强度: $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  /// 根据强度与主题亮度返回可读的颜色（深色模式使用浅色变体保证对比度）
  Color _getStrengthColor(int strength, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    if (strength < 40) return colorScheme.error;
    if (strength < 70) return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
    if (strength < 90) return isDark ? Colors.amber.shade200 : Colors.amber.shade800;
    return isDark ? Colors.green.shade300 : Colors.green.shade700;
  }
}
