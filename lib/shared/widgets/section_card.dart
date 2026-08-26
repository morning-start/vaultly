import 'package:flutter/material.dart';
import '../../ui/theme/tokens.dart';

/// 表单分区卡片
///
/// 将相关联的表单字段分组展示，带标题与图标，视觉上对齐设计令牌。
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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceL),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: colorScheme.primary),
                  const SizedBox(width: AppTokens.spaceS),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceL),
            ...children,
          ],
        ),
      ),
    );
  }
}
