import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/vault_entry.dart';
import '../models/folder.dart';
import '../models/sync_metadata.dart';

/// 本地存储仓库
///
/// 使用 JSON 文件存储数据，无需代码生成
class LocalStorageRepository {
  static LocalStorageRepository? _instance;
  static final Map<String, dynamic> _cache = {};
  static bool _initialized = false;

  late final Directory _storageDir;

  LocalStorageRepository._(this._storageDir);

  /// 获取仓库实例
  static Future<LocalStorageRepository> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    final dir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${dir.path}/vaultly_storage');

    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }

    _instance = LocalStorageRepository._(storageDir);
    await _instance!._loadAll();
    _initialized = true;

    return _instance!;
  }

  /// 检查是否已初始化
  static bool get isInitialized => _initialized;

  /// 获取存储文件路径
  File _getFile(String name) {
    return File('${_storageDir.path}/$name.json');
  }

  /// 加载所有数据到缓存
  Future<void> _loadAll() async {
    final files = ['entries', 'folders', 'sync_metadata'];
    for (final file in files) {
      final storageFile = _getFile(file);
      if (await storageFile.exists()) {
        try {
          final content = await storageFile.readAsString();
          _cache[file] = jsonDecode(content);
        } catch (e) {
          _cache[file] = [];
        }
      } else {
        _cache[file] = [];
      }
    }
  }

  /// 保存数据到文件
  Future<void> _save(String name, dynamic data) async {
    _cache[name] = data;
    final file = _getFile(name);
    await file.writeAsString(jsonEncode(data));
  }

  // ==================== 条目操作 ====================

  /// 获取所有条目
  List<VaultEntry> getEntries() {
    final data = _cache['entries'] as List? ?? [];
    return data.map((e) => VaultEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 根据 UUID 获取条目
  VaultEntry? getEntryByUuid(String uuid) {
    final entries = getEntries();
    try {
      return entries.firstWhere((e) => e.uuid == uuid);
    } catch (e) {
      return null;
    }
  }

  /// 添加条目
  Future<void> addEntry(VaultEntry entry) async {
    entry.touch();
    final entries = getEntries();
    entries.add(entry);
    await _save('entries', entries.map((e) => e.toJson()).toList());

    // 创建同步元数据
    await addSyncMetadata(SyncMetadata(entryUuid: entry.uuid));
  }

  /// 更新条目
  Future<void> updateEntry(VaultEntry entry) async {
    entry.touch();
    final entries = getEntries();
    final index = entries.indexWhere((e) => e.uuid == entry.uuid);
    if (index >= 0) {
      entries[index] = entry;
      await _save('entries', entries.map((e) => e.toJson()).toList());

      // 更新同步元数据
      final syncMeta = getSyncMetadata(entry.uuid);
      if (syncMeta != null) {
        syncMeta.isSynced = false;
        syncMeta.localModifiedAt = DateTime.now();
        await updateSyncMetadata(syncMeta);
      }
    }
  }

  /// 删除条目（软删除）
  Future<void> deleteEntry(String uuid) async {
    final entries = getEntries();
    entries.removeWhere((e) => e.uuid == uuid);
    await _save('entries', entries.map((e) => e.toJson()).toList());

    // 更新同步元数据为已删除
    final syncMeta = getSyncMetadata(uuid);
    if (syncMeta != null) {
      syncMeta.isDeleted = true;
      syncMeta.isSynced = false;
      syncMeta.localModifiedAt = DateTime.now();
      await updateSyncMetadata(syncMeta);
    }
  }

  /// 永久删除条目
  Future<void> permanentlyDeleteEntry(String uuid) async {
    await deleteEntry(uuid);
    await deleteSyncMetadata(uuid);
  }

  /// 根据类型获取条目
  List<VaultEntry> getEntriesByType(EntryType type) {
    return getEntries().where((e) => e.type == type).toList();
  }

  /// 搜索条目
  List<VaultEntry> searchEntries(String query) {
    final lowerQuery = query.toLowerCase();
    return getEntries().where((e) {
      return e.title.toLowerCase().contains(lowerQuery) ||
          e.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// 获取收藏条目
  List<VaultEntry> getFavoriteEntries() {
    return getEntries().where((e) => e.isFavorite).toList();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String uuid) async {
    final entry = getEntryByUuid(uuid);
    if (entry != null) {
      entry.isFavorite = !entry.isFavorite;
      await updateEntry(entry);
    }
  }

  /// 获取所有标签
  List<String> getAllTags() {
    final tags = <String>{};
    for (final entry in getEntries()) {
      tags.addAll(entry.tags);
    }
    return tags.toList()..sort();
  }

  // ==================== 文件夹操作 ====================

  /// 获取所有文件夹
  List<Folder> getFolders() {
    final data = _cache['folders'] as List? ?? [];
    return data.map((e) => Folder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 添加文件夹
  Future<void> addFolder(Folder folder) async {
    folder.touch();
    final folders = getFolders();
    folders.add(folder);
    await _save('folders', folders.map((f) => f.toJson()).toList());
  }

  /// 更新文件夹
  Future<void> updateFolder(Folder folder) async {
    folder.touch();
    final folders = getFolders();
    final index = folders.indexWhere((f) => f.uuid == folder.uuid);
    if (index >= 0) {
      folders[index] = folder;
      await _save('folders', folders.map((f) => f.toJson()).toList());
    }
  }

  /// 删除文件夹
  Future<void> deleteFolder(String uuid) async {
    final folders = getFolders();
    folders.removeWhere((f) => f.uuid == uuid);
    await _save('folders', folders.map((f) => f.toJson()).toList());
  }

  // ==================== 同步元数据操作 ====================

  /// 获取所有同步元数据
  List<SyncMetadata> getSyncMetadatas() {
    final data = _cache['sync_metadata'] as List? ?? [];
    return data.map((e) => SyncMetadata.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 根据 UUID 获取同步元数据
  SyncMetadata? getSyncMetadata(String entryUuid) {
    final metadatas = getSyncMetadatas();
    try {
      return metadatas.firstWhere((m) => m.entryUuid == entryUuid);
    } catch (e) {
      return null;
    }
  }

  /// 添加同步元数据
  Future<void> addSyncMetadata(SyncMetadata metadata) async {
    final metadatas = getSyncMetadatas();
    metadatas.add(metadata);
    await _save('sync_metadata', metadatas.map((m) => m.toJson()).toList());
  }

  /// 更新同步元数据
  Future<void> updateSyncMetadata(SyncMetadata metadata) async {
    final metadatas = getSyncMetadatas();
    final index = metadatas.indexWhere((m) => m.entryUuid == metadata.entryUuid);
    if (index >= 0) {
      metadatas[index] = metadata;
      await _save('sync_metadata', metadatas.map((m) => m.toJson()).toList());
    }
  }

  /// 删除同步元数据
  Future<void> deleteSyncMetadata(String entryUuid) async {
    final metadatas = getSyncMetadatas();
    metadatas.removeWhere((m) => m.entryUuid == entryUuid);
    await _save('sync_metadata', metadatas.map((m) => m.toJson()).toList());
  }

  /// 获取未同步的条目
  List<SyncMetadata> getUnsyncedMetadata() {
    return getSyncMetadatas().where((m) => !m.isSynced).toList();
  }

  // ==================== 数据管理 ====================

  /// 清除所有数据
  Future<void> clearAll() async {
    _cache.clear();
    await _save('entries', []);
    await _save('folders', []);
    await _save('sync_metadata', []);
  }

  /// 导出所有数据
  Map<String, dynamic> exportAll() {
    return {
      'entries': _cache['entries'] ?? [],
      'folders': _cache['folders'] ?? [],
      'sync_metadata': _cache['sync_metadata'] ?? [],
    };
  }

  /// 导入数据
  Future<void> importAll(Map<String, dynamic> data) async {
    await _save('entries', data['entries'] ?? []);
    await _save('folders', data['folders'] ?? []);
    await _save('sync_metadata', data['sync_metadata'] ?? []);
  }
}
