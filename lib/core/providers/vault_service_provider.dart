import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vault_service.dart';
import '../models/vault_entry.dart';

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

final vaultEntriesProvider = FutureProvider<List<VaultEntry>>((ref) async {
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getAllEntries();
});

final vaultEntriesByTypeProvider = FutureProvider.family<List<VaultEntry>, EntryType>((ref, type) async {
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getEntriesByType(type);
});

final vaultSearchProvider = FutureProvider.family<List<VaultEntry>, String>((ref, query) async {
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.searchEntries(query);
});

final vaultFavoritesProvider = FutureProvider<List<VaultEntry>>((ref) async {
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getFavorites();
});

final vaultTagsProvider = Provider<List<String>>((ref) {
  final vaultService = ref.watch(vaultServiceProvider);
  return vaultService.getAllTags();
});
