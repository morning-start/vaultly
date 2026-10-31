import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vault_service.dart';
import '../domain/vault_entry.dart';
import '../domain/vault_notifier.dart';
import '../domain/search/entry_search_strategy.dart';
import '../../auth/presentation/auth_providers.dart';

/// Vault 服务提供者
///
/// VaultService 封装加密存储细节（持久化、字段级加解密），
/// 对外状态经 [vaultNotifierProvider] 暴露。
final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService.instance;
});

/// Vault 状态提供者（应用内唯一条目数据源）
///
/// 创建时接线 [SessionKeyBridge]：
/// - 密钥发布（解锁/改密）→ 加载保险库 / 重加密；
/// - 密钥回收（锁定）→ 清空内存态。
final vaultNotifierProvider =
    StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final notifier = VaultNotifier(ref.watch(vaultServiceProvider));
  final bridge = ref.watch(sessionKeyBridgeProvider);

  void onPublished(Uint8List key) {
    // 改密与解锁都走 publish：未加载时加载，已加载时用新密钥重加密
    if (notifier.isLoaded) {
      notifier.rotateKey(key);
    } else {
      notifier.unlock(key);
    }
  }

  void onRevoked() {
    notifier.lock();
  }

  /// DEK 迁移：确保数据已用旧密钥（masterSecret）加载完成，
  /// 再用新密钥（DEK）重加密。必须 await，否则会出现
  /// 「数据还没加载完就重加密」→ 用空列表覆盖磁盘的严重后果。
  Future<void> onMigrate(Uint8List oldKey, Uint8List newKey) async {
    await notifier.unlock(oldKey);
    await notifier.rotateKey(newKey);
  }

  bridge.onPublished(onPublished);
  bridge.onRevoked(onRevoked);
  bridge.onMigrate(onMigrate);
  ref.onDispose(() {
    bridge.removeListeners(
      published: onPublished,
      revoked: onRevoked,
      migrator: onMigrate,
    );
  });

  // 补偿时序竞争：密钥可能在 provider 首次被 watch 之前就已发布
  // （例如 setupPassword 后直接进入主界面），此时监听器错过发布事件。
  // bridge 缓存的密钥仍有效时立即消费；unlock 内部幂等，重复消费无害。
  final pendingKey = bridge.key;
  if (pendingKey != null && !notifier.isLoaded) {
    notifier.unlock(pendingKey);
  }

  return notifier;
});

/// Vault 条目列表（同步快照，无 Future 开销）
///
/// **只含活跃条目**：回收站里的墓碑不参与界面展示。
/// 需要含墓碑的全量列表（同步/合并且用）请读
/// `vaultNotifierProvider.allEntries`。
final vaultEntriesProvider = Provider<List<VaultEntry>>((ref) {
  return ref.watch(vaultNotifierProvider).entries;
});

/// 回收站条目（墓碑，按删除时间倒序）
final vaultTrashedEntriesProvider = Provider<List<VaultEntry>>((ref) {
  return ref.watch(vaultNotifierProvider).trashedEntries;
});

/// 按类型筛选的条目列表
final vaultEntriesByTypeProvider =
    Provider.family<List<VaultEntry>, EntryType>((ref, type) {
  return ref.watch(vaultEntriesProvider).where((e) => e.type == type).toList();
});

/// 搜索结果（空查询返回全部）
final vaultSearchProvider =
    Provider.family<List<VaultEntry>, String>((ref, query) {
  if (query.isEmpty) return ref.watch(vaultEntriesProvider);

  final lowerQuery = query.toLowerCase();
  const basicStrategy = BasicSearchStrategy();

  return ref
      .watch(vaultEntriesProvider)
      .where((entry) =>
          basicStrategy.matches(entry, lowerQuery) ||
          SearchStrategyFactory.getStrategy(entry.type)
              .matches(entry, lowerQuery))
      .toList();
});

/// 收藏条目
final vaultFavoritesProvider = Provider<List<VaultEntry>>((ref) {
  return ref.watch(vaultEntriesProvider).where((e) => e.isFavorite).toList();
});

/// 全部标签（去重排序）
final vaultTagsProvider = Provider<List<String>>((ref) {
  final tags = <String>{};
  for (final entry in ref.watch(vaultEntriesProvider)) {
    tags.addAll(entry.tags);
  }
  return tags.toList()..sort();
});

/// 统计信息
final vaultStatsProvider = Provider<Map<String, int>>((ref) {
  final entries = ref.watch(vaultEntriesProvider);
  return {
    'total': entries.length,
    'login': entries.where((e) => e.type == EntryType.login).length,
    'bankCard': entries.where((e) => e.type == EntryType.bankCard).length,
    'secureNote': entries.where((e) => e.type == EntryType.secureNote).length,
    'identity': entries.where((e) => e.type == EntryType.identity).length,
    'favorites': entries.where((e) => e.isFavorite).length,
  };
});

/// 单个条目（路由参数驱动）
final vaultEntryByIdProvider =
    Provider.family<VaultEntry?, String>((ref, id) {
  for (final entry in ref.watch(vaultEntriesProvider)) {
    if (entry.id == id) return entry;
  }
  return null;
});
