import 'package:flutter/material.dart';
import 'package:vaultly_core/vaultly_core.dart';
import '../../features/vault/presentation/widgets/entry_type_helper.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/theme/vaultly_colors.dart';

/// 类型图标徽章
///
/// 统一的类型色视觉锚点：类型色 15% tint 圆角底 + 类型色图标
/// （原型 `.icon-badge`：44px / 圆角 13，图标 22）。
/// 列表项（44px）、详情页头部（56px）、分组头（16px）复用。
class TypeBadge extends StatelessWidget {
  final EntryType type;
  final double size;
  final double? iconSize;

  const TypeBadge({
    super.key,
    required this.type,
    this.size = AppTokens.iconBadgeSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.entryType(type);
    final effectiveIcon = iconSize ?? size * 0.5;
    final radius = size >= AppTokens.iconBadgeLarge
        ? AppTokens.badgeRadiusLarge
        : AppTokens.badgeRadius;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(38), // 15% tint
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        EntryTypeHelper.getIcon(type),
        color: color,
        size: effectiveIcon,
      ),
    );
  }
}
