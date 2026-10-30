import 'package:flutter/material.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/theme/vaultly_colors.dart';

/// 表单分区
///
/// 对齐原型：分区标题为 12/500 muted 的小标签（上 24 / 下 10），
/// 内容包裹在 surface 卡片内（line 描边 + 圆角 18）。
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: colorScheme.textMuted,
                ),
              ),
              const Spacer(),
              if (icon != null)
                Icon(icon, size: 14, color: colorScheme.textFaint),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: padding ?? const EdgeInsets.all(AppTokens.spaceL),
          decoration: BoxDecoration(
            color: colorScheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusL),
            border: Border.all(color: colorScheme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );
  }
}
