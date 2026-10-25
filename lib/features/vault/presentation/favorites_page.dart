import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/vault_entry.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../ui/theme/tokens.dart';
import '../../../features/tools/clipboard_service.dart';
import 'widgets/empty_state.dart';
import 'widgets/entry_card_widget.dart';

/// 收藏页
///
/// 展示所有收藏条目，按更新时间倒序；支持滑动复制主字段/取消收藏。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vaultEntriesProvider);
    final favorites = entries.where((e) => e.isFavorite).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    void navigateToDetail(VaultEntry entry) {
      context.push('/entry/${entry.uuid}');
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
      await vaultService.toggleFavorite(entry.uuid);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: favorites.isEmpty
          ? EmptyState.favorites()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceL,
                vertical: AppTokens.spaceS,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final entry = favorites[index];
                return EntryCardWidget(
                  key: ValueKey(entry.uuid),
                  entry: entry,
                  onTap: () => navigateToDetail(entry),
                  onCopyPrimaryField: () => copyPrimaryField(entry),
                  onToggleFavorite: () => unfavorite(entry),
                );
              },
            ),
    );
  }
}
