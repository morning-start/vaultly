import 'package:flutter/material.dart';
import '../../domain/vault_entry.dart';
import 'entry_type_helper.dart';
import '../../../../ui/theme/tokens.dart';

/// 条目类型选择器（可视化网格）
class EntryTypePicker extends StatelessWidget {
  final EntryType value;
  final ValueChanged<EntryType> onChanged;

  const EntryTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const List<EntryType> _types = [
    EntryType.login,
    EntryType.bankCard,
    EntryType.secureNote,
    EntryType.identity,
    EntryType.custom,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: _types.map((type) {
        final selected = type == value;
        final typeColor = EntryTypeHelper.getColor(type);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceXS,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusM),
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: AppTokens.animFast,
                curve: AppTokens.easeStandard,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceM,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            typeColor.withAlpha(50),
                            typeColor.withAlpha(20),
                          ],
                        )
                      : null,
                  color: selected ? null : colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTokens.radiusM),
                  border: Border.all(
                    color: selected
                        ? typeColor.withAlpha(100)
                        : colorScheme.outlineVariant.withAlpha(60),
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: typeColor.withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.15 : 1.0,
                      duration: AppTokens.animFast,
                      child: Icon(
                        EntryTypeHelper.getIcon(type),
                        size: 22,
                        color: selected
                            ? typeColor
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXS),
                    Text(
                      EntryTypeHelper.getName(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: selected
                            ? typeColor
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
