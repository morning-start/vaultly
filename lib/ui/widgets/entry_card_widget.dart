import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/vault_entry.dart';
import '../theme/tokens.dart';
import 'entry_type_helper.dart';

class EntryCardWidget extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;

  const EntryCardWidget({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = EntryTypeHelper.getColor(entry.type);
    final typeName = EntryTypeHelper.getName(entry.type);

    // 副标题：标签（优先）或类型名 + 更新时间
    final tagText = entry.tags.isNotEmpty ? entry.tags.join(', ') : typeName;
    final timeText = DateFormat('MM-dd HH:mm').format(entry.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceL,
            vertical: AppTokens.spaceM,
          ),
          child: Row(
            children: [
              // 类型圆角徽章（语义色）
              Container(
                width: AppTokens.iconBadgeSize,
                height: AppTokens.iconBadgeSize,
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(AppTokens.radiusM),
                ),
                child: Icon(
                  EntryTypeHelper.getIcon(entry.type),
                  color: typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTokens.spaceL),
              // 标题与副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceXS),
                    Text(
                      '$tagText · $timeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.spaceS),
              // 收藏星标（常驻，未收藏用浅色描边）
              Icon(
                entry.isFavorite ? Icons.star : Icons.star_border,
                size: 22,
                color: entry.isFavorite
                    ? colorScheme.tertiary
                    : colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
