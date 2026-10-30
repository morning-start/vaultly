import 'package:flutter/material.dart';
import '../../domain/vault_entry.dart';
import 'entry_type_helper.dart';
import '../../../../ui/theme/tokens.dart';
import '../../../../ui/theme/vaultly_colors.dart';

/// 条目类型选择器（原型 `.type-grid`）
///
/// 四列网格：40 徽章（圆角 12）+ 12/500 文字。
/// 选中态：primary-soft 底、主色 45% 描边、徽章与文字转主色。
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const columns = 4;
        final cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final type in _types)
              SizedBox(
                width: cellWidth,
                child: _TypeCell(
                  type: type,
                  selected: type == value,
                  onTap: () => onChanged(type),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TypeCell extends StatelessWidget {
  final EntryType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCell({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = colorScheme.entryType(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTokens.animFast,
          curve: AppTokens.easeStandard,
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primarySoft : colorScheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withAlpha(115)
                  : colorScheme.hairline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary.withAlpha(51)
                      : typeColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(AppTokens.radiusM - 2),
                ),
                child: Icon(
                  EntryTypeHelper.getIcon(type),
                  size: 20,
                  color: selected ? colorScheme.primary : typeColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                EntryTypeHelper.getName(type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? colorScheme.primary : colorScheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
