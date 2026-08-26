import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vault_service.dart';
import '../domain/vault_entry.dart';
import '../../auth/presentation/auth_providers.dart';

/// Vault 服务提供者
///
/// 注意：VaultService 目前使用单例模式，后续版本将迁移为纯 Riverpod 管理。
/// 新代码建议直接使用 vaultServiceProvider。
final vaultServiceProvider = Provider<VaultService>((ref) {
  final service = VaultService.instance;

  // 监听认证状态变化，同步加密密钥
  final authNotifier = ref.watch(authNotifierProvider.notifier);
  final encryptionKey = authNotifier.encryptionKey;

  if (encryptionKey != null) {
    service.setEncryptionKey(encryptionKey);
  }

  return service;
});

/// Vault 数据变更通知器
///
/// 用于通知 Vault 数据发生变化，触发相关 Provider 刷新
final vaultChangeNotifierProvider =
    StateNotifierProvider<VaultChangeNotifier, int>((ref) {
  return VaultChangeNotifier();
});

/// Vault 变更通知器
///
/// 使用简单的计数器模式，每次数据变更时递增计数
/// 其他 Provider 可以监听这个计数器来触发刷新
class VaultChangeNotifier extends StateNotifier<int> {
  VaultChangeNotifier() : super(0);

  /// 通知数据已变更
  void notifyChanged() {
    state = state + 1;
  }

  /// 重置计数器
  void reset() {
    state = 0;
  }
}

/// Vault 条目列表提供者
///
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultEntriesProvider = FutureProvider<List<VaultEntry>>((ref) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);

  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getAllEntries();
});

/// 按类型筛选的 Vault 条目提供者
///
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultEntriesByTypeProvider =
    FutureProvider.family<List<VaultEntry>, EntryType>((ref, type) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);

  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getEntriesByType(type);
});

/// Vault 搜索提供者
///
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultSearchProvider =
    FutureProvider.family<List<VaultEntry>, String>((ref, query) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);

  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.searchEntries(query);
});

/// Vault 收藏列表提供者
///
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultFavoritesProvider = FutureProvider<List<VaultEntry>>((ref) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);

  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getFavorites();
});

/// Vault 标签列表提供者
///
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultTagsProvider = FutureProvider<List<String>>((ref) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);

  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getAllTags();
});

/// Vault 统计信息提供者
///
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);

  final vaultService = ref.watch(vaultServiceProvider);
  final entries = await vaultService.getAllEntries();

  return {
    'total': entries.length,
    'login': entries.where((e) => e.type == EntryType.login).length,
    'bankCard': entries.where((e) => e.type == EntryType.bankCard).length,
    'secureNote': entries.where((e) => e.type == EntryType.secureNote).length,
    'identity': entries.where((e) => e.type == EntryType.identity).length,
    'favorites': entries.where((e) => e.isFavorite).length,
  };
});

/// 加密密钥提供者
///
/// 提供当前会话的加密密钥，供需要加密解密的服务使用
final encryptionKeyProvider = Provider<Uint8List?>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);
  return authNotifier.encryptionKey;
});
