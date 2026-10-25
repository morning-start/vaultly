import 'package:flutter/material.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/theme/vaultly_colors.dart';

/// 列表分组头
///
/// 收藏置顶组 / 类型分组的统一标题行。
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final IconData? icon;
  final Color? iconColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceXS,
        AppTokens.spaceL,
        AppTokens.spaceXS,
        AppTokens.spaceM,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor ?? colorScheme.favorite),
            const SizedBox(width: AppTokens.spaceS),
          ],
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppTokens.spaceS),
            Text(
              '$count',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withAlpha(160),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
