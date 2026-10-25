import 'package:flutter/material.dart';
import '../../features/vault/domain/vault_entry.dart';
import '../../features/vault/presentation/widgets/entry_type_helper.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/theme/vaultly_colors.dart';

/// 类型图标徽章
///
/// 统一的类型色视觉锚点：类型色 12% tint 圆角底 + 类型色图标。
/// 列表项（44px）、详情页头部（64px）、分组头（16px）复用。
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(31), // 12% tint
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        EntryTypeHelper.getIcon(type),
        color: color,
        size: effectiveIcon,
      ),
    );
  }
}
