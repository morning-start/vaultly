import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/vault_entry.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../../features/tools/clipboard_service.dart';
import 'widgets/empty_state.dart';
import 'widgets/entry_card_widget.dart';

/// 收藏页
///
/// 与保险库页共用行式条目与分组卡片：大标题 + 收藏数量副标题 +
/// 单卡片列表；支持滑动复制主字段 / 取消收藏。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vaultEntriesProvider);
    final favorites = entries.where((e) => e.isFavorite).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    void navigateToDetail(VaultEntry entry) {
      context.push('/entry/${entry.id}');
    }

    Future<void> copyPrimaryField(VaultEntry entry) async {
      final value = switch (entry) {
        LoginEntry l when (l.password ?? '').isNotEmpty => l.password,
        BankCardEntry b when (b.cardNumber ?? '').isNotEmpty =>
          b.cardNumber?.replaceAll(' ', ''),
        _ => null,
      };
      if (value == null) {
        if (context.mounted) AppToast.show(context, '该条目没有可复制的机密字段');
        return;
      }
      await ClipboardService().copySensitive(value, label: entry.title);
      if (context.mounted) {
        AppToast.show(context, '${entry.title} 已复制（30 秒后自动清除）');
      }
    }

    Future<void> unfavorite(VaultEntry entry) async {
      final vaultService = ref.read(vaultServiceProvider);
      await vaultService.toggleFavorite(entry.id);
    }

    return Scaffold(
      backgroundColor: colorScheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 120 + bottomInset),
          children: [
            Text('收藏', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 4),
            Text(
              '${favorites.length} 个收藏条目',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.textMuted),
            ),
            const SizedBox(height: 20),
            if (favorites.isEmpty)
              EmptyState.favorites(onBrowsePressed: () => context.go('/vault'))
            else
              _FavoritesGroup(
                entries: favorites,
                onNavigate: navigateToDetail,
                onCopyPrimaryField: copyPrimaryField,
                onToggleFavorite: unfavorite,
              ),
          ],
        ),
      ),
    );
  }
}

/// 收藏分组卡片（行间 1px 分隔）
class _FavoritesGroup extends StatelessWidget {
  final List<VaultEntry> entries;
  final void Function(VaultEntry) onNavigate;
  final void Function(VaultEntry) onCopyPrimaryField;
  final void Function(VaultEntry) onToggleFavorite;

  const _FavoritesGroup({
    required this.entries,
    required this.onNavigate,
    required this.onCopyPrimaryField,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i > 0) {
        children.add(
          Divider(height: 1, thickness: 1, color: colorScheme.hairline),
        );
      }
      children.add(
        EntryCardWidget(
          key: ValueKey(entry.id),
          entry: entry,
          onTap: () => onNavigate(entry),
          onCopyPrimaryField: () => onCopyPrimaryField(entry),
          onToggleFavorite: () => onToggleFavorite(entry),
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
