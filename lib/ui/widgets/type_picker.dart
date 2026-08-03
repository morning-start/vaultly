import 'package:flutter/material.dart';
import '../../core/models/vault_entry.dart';
import '../theme/tokens.dart';
import 'entry_type_helper.dart';

/// 条目类型选择器（可视化网格）
///
/// 用图标 + 类型名的卡片网格替代下拉框，选中项高亮。
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
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXS),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusM),
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: AppTokens.animFast,
                curve: AppTokens.easeStandard,
                padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceM),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTokens.radiusM),
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      EntryTypeHelper.getIcon(type),
                      size: 22,
                      color: selected
                          ? colorScheme.onSecondaryContainer
                          : typeColor,
                    ),
                    const SizedBox(height: AppTokens.spaceXS),
                    Text(
                      EntryTypeHelper.getName(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
