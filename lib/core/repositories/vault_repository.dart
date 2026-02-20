import '../models/vault_entry.dart';
import 'local_storage_repository.dart';

/// 保险库数据仓库
///
/// 参考文档: wiki/03-模块设计/保险库模块.md
/// 负责条目的 CRUD 操作和查询
class VaultRepository {
  late final LocalStorageRepository _storage;

  VaultRepository._(this._storage);

  /// 创建仓库实例
  static Future<VaultRepository> create() async {
    final storage = await LocalStorageRepository.getInstance();
    return VaultRepository._(storage);
  }

  // ==================== CRUD 操作 ====================

  /// 添加条目
  Future<String> addEntry(VaultEntry entry) async {
    await _storage.addEntry(entry);
    return entry.uuid;
  }

  /// 更新条目
  Future<void> updateEntry(VaultEntry entry) async {
    await _storage.updateEntry(entry);
  }

  /// 删除条目（软删除）
  Future<void> deleteEntry(String uuid) async {
    await _storage.deleteEntry(uuid);
  }

  /// 永久删除条目
  Future<void> permanentlyDeleteEntry(String uuid) async {
    await _storage.permanentlyDeleteEntry(uuid);
  }

  // ==================== 查询操作 ====================

  /// 获取所有条目
  List<VaultEntry> getAllEntries() {
    return _storage.getEntries();
  }

  /// 根据 UUID 获取条目
  VaultEntry? getEntryByUuid(String uuid) {
    return _storage.getEntryByUuid(uuid);
  }

  /// 根据类型获取条目
  List<VaultEntry> getEntriesByType(EntryType type) {
    return _storage.getEntriesByType(type);
  }

  /// 搜索条目
  List<VaultEntry> searchEntries(String query) {
    return _storage.searchEntries(query);
  }

  // ==================== 收藏操作 ====================

  /// 获取收藏条目
  List<VaultEntry> getFavoriteEntries() {
    return _storage.getFavoriteEntries();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String uuid) async {
    await _storage.toggleFavorite(uuid);
  }

  // ==================== 标签操作 ====================

  /// 获取所有标签
  List<String> getAllTags() {
    return _storage.getAllTags();
  }

  /// 根据标签获取条目
  List<VaultEntry> getEntriesByTag(String tag) {
    return _storage.getEntries().where((e) => e.tags.contains(tag)).toList();
  }

  // ==================== 文件夹操作 ====================

  /// 获取所有文件夹
  List<Folder> getAllFolders() {
    return _storage.getFolders();
  }

  /// 添加文件夹
  Future<void> addFolder(Folder folder) async {
    await _storage.addFolder(folder);
  }

  /// 更新文件夹
  Future<void> updateFolder(Folder folder) async {
    await _storage.updateFolder(folder);
  }

  /// 删除文件夹
  Future<void> deleteFolder(String uuid) async {
    await _storage.deleteFolder(uuid);
  }

  /// 根据文件夹获取条目
  List<VaultEntry> getEntriesByFolder(String folderUuid) {
    return _storage
        .getEntries()
        .where((e) => e.folderId == folderUuid)
        .toList();
  }

  // ==================== 数据管理 ====================

  /// 清除所有数据
  Future<void> clearAll() async {
    await _storage.clearAll();
  }

  /// 导出所有数据
  Map<String, dynamic> exportAll() {
    return _storage.exportAll();
  }

  /// 导入数据
  Future<void> importAll(Map<String, dynamic> data) async {
    await _storage.importAll(data);
  }

  /// 获取同步元数据
  SyncMetadata? getSyncMetadata(String entryUuid) {
    return _storage.getSyncMetadata(entryUuid);
  }

  /// 获取未同步条目
  List<SyncMetadata> getUnsyncedMetadata() {
    return _storage.getUnsyncedMetadata();
  }

  /// 更新同步元数据
  Future<void> updateSyncMetadata(SyncMetadata metadata) async {
    await _storage.updateSyncMetadata(metadata);
  }
}
