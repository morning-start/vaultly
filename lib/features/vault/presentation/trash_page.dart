import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/vault_entry.dart';
import '../domain/vault_tombstone.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/type_badge.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import 'widgets/empty_state.dart';

/// 回收站（原型风格：大标题 + 说明条 + 行式卡片列表）
///
/// ADR-006 R3 的配套界面：删除后的条目会变成「墓碑」并继续同步，
/// 在这里可以恢复或彻底清除。没有这个入口，墓碑对用户就是不可见状态，
/// 既恢复不了也清不掉（v1.0 遗漏项 F7）。
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    VaultEntry entry,
  ) async {
    final ok = await ref.read(vaultNotifierProvider.notifier).restoreEntry(
          entry.id,
        );
    if (!context.mounted) return;
    AppToast.show(context, ok ? '已恢复「${entry.title}」' : '恢复失败，请重试');
  }

  Future<void> _purge(
    BuildContext context,
    WidgetRef ref,
    VaultEntry entry,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '彻底删除？',
      content: '「${entry.title}」将从本机与云端备份中永久移除，无法恢复。',
      confirmLabel: '彻底删除',
      icon: Icons.delete_forever_outlined,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(vaultNotifierProvider.notifier).purgeEntry(
          entry.id,
        );
    if (!context.mounted) return;
    AppToast.show(context, ok ? '已彻底删除' : '删除失败，请重试');
  }

  Future<void> _purgeAll(BuildContext context, WidgetRef ref, int count) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '清空回收站？',
      content: '$count 个条目将从本机与云端备份中永久移除，无法恢复。',
      confirmLabel: '清空',
      icon: Icons.delete_sweep_outlined,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(vaultNotifierProvider.notifier).purgeAllTrashed();
    if (!context.mounted) return;
    AppToast.show(context, ok ? '回收站已清空' : '清空失败，请重试');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashed = ref.watch(vaultTrashedEntriesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colorScheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavBar(context, ref, trashed.length),
            Expanded(
              child: trashed.isEmpty
                  ? EmptyState(
                      icon: Icons.delete_outline_rounded,
                      title: '回收站是空的',
                      subtitle: '删除的条目会先放到这里，30 天后自动清除',
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 32 + bottomInset),
                      children: [
                        _buildNotice(textTheme, colorScheme, trashed.length),
                        const SizedBox(height: AppTokens.spaceL),
                        _TrashGroup(
                          entries: trashed,
                          onRestore: (e) => _restore(context, ref, e),
                          onPurge: (e) => _purge(context, ref, e),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, WidgetRef ref, int count) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: AppTokens.navBarHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
              tooltip: '返回',
            ),
          ),
          Text('回收站', style: Theme.of(context).textTheme.titleMedium),
          if (count > 0)
            Positioned(
              right: 8,
              child: TextButton(
                onPressed: () => _purgeAll(context, ref, count),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('清空'),
              ),
            ),
        ],
      ),
    );
  }

  /// 说明条：让用户明白「删除为什么还在」「什么时候真正消失」
  Widget _buildNotice(TextTheme textTheme, ColorScheme colorScheme, int count) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceM),
      decoration: BoxDecoration(
        color: colorScheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: colorScheme.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count 个已删除条目。删除记录会一起同步到其他设备，'
              '所以在这里恢复的条目也会同步回去；超过 30 天后自动永久清除。',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.textMuted,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 回收站分组卡片（surface 底 + 描边 + 行间分隔线）
class _TrashGroup extends StatelessWidget {
  final List<VaultEntry> entries;
  final void Function(VaultEntry) onRestore;
  final void Function(VaultEntry) onPurge;

  const _TrashGroup({
    required this.entries,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    for (var i = 0; i < entries.length; i++) {
      if (i > 0) {
        children.add(
          Divider(height: 1, thickness: 1, color: colorScheme.hairline),
        );
      }
      children.add(
        _TrashRow(
          key: ValueKey(entries[i].id),
          entry: entries[i],
          onRestore: () => onRestore(entries[i]),
          onPurge: () => onPurge(entries[i]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// 回收站行：类型徽章 + 标题 + 删除时间/剩余天数 + 恢复 / 彻底删除
class _TrashRow extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrashRow({
    super.key,
    required this.entry,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: AppTokens.listRowMinHeight),
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      child: Row(
        children: [
          TypeBadge(type: entry.type),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceXS),
          _RowAction(
            icon: Icons.restore_rounded,
            tooltip: '恢复',
            color: colorScheme.primary,
            onTap: onRestore,
          ),
          _RowAction(
            icon: Icons.delete_forever_rounded,
            tooltip: '彻底删除',
            color: colorScheme.error,
            onTap: onPurge,
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final deletedAt = entry.deletedAt;
    final remaining = tombstoneRemainingDays(entry);
    final left = remaining <= 0 ? '即将清除' : '剩余 $remaining 天';
    if (deletedAt == null) return left;

    final stamp =
        '${deletedAt.month}/${deletedAt.day} '
        '${deletedAt.hour.toString().padLeft(2, '0')}:'
        '${deletedAt.minute.toString().padLeft(2, '0')}';
    return '删除于 $stamp · $left';
  }
}

/// 行内图标动作（44x44 触达区）
class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
