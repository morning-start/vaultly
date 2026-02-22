import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vault_service.dart';
import '../models/vault_entry.dart';

/// Vault 服务提供者 - 单例模式
///
/// 使用 VaultService.instance 确保全局只有一个实例
final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService.instance;
});

/// Vault 数据变更通知器
/// 
/// 用于通知 Vault 数据发生变化，触发相关 Provider 刷新
final vaultChangeNotifierProvider = StateNotifierProvider<VaultChangeNotifier, int>((ref) {
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
final vaultEntriesByTypeProvider = FutureProvider.family<List<VaultEntry>, EntryType>((ref, type) async {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);
  
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getEntriesByType(type);
});

/// Vault 搜索提供者
/// 
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultSearchProvider = FutureProvider.family<List<VaultEntry>, String>((ref, query) async {
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
final vaultTagsProvider = Provider<List<String>>((ref) {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);
  
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getAllTags();
});

/// Vault 统计信息提供者
/// 
/// 监听 vaultChangeNotifierProvider，数据变更时自动刷新
final vaultStatsProvider = Provider<Map<String, int>>((ref) {
  // 监听变更通知器
  ref.watch(vaultChangeNotifierProvider);
  
  final vaultService = ref.watch(vaultServiceProvider);
  final entries = vaultService.getAllEntries();
  
  return {
    'total': entries.length,
    'login': entries.where((e) => e.type == EntryType.login).length,
    'bankCard': entries.where((e) => e.type == EntryType.bankCard).length,
    'secureNote': entries.where((e) => e.type == EntryType.secureNote).length,
    'identity': entries.where((e) => e.type == EntryType.identity).length,
    'favorites': entries.where((e) => e.isFavorite).length,
  };
});
