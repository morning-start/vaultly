import 'package:flutter/material.dart';
import '../../core/utils/password_policy.dart';

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

    final color = _getStrengthColor(strength);
    final label = PasswordPolicy.getStrengthLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength / 100,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: height ?? 4,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
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

  Color _getStrengthColor(int strength) {
    final colorName = PasswordPolicy.getStrengthColor(strength);
    switch (colorName) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'lightGreen':
        return Colors.lightGreen;
      case 'green':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
