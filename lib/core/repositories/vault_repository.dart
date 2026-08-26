import '../../features/vault/domain/vault_entry.dart';
import '../../features/vault/domain/folder.dart';

/// 保险库数据仓库
///
/// 参考文档: wiki/03-模块设计/保险库模块.md
/// 负责条目的 CRUD 操作和查询
class VaultRepository {
  final List<VaultEntry> _entries = [];
  final List<Folder> _folders = [];

  VaultRepository._();

  /// 创建仓库实例
  static Future<VaultRepository> create() async {
    return VaultRepository._();
  }

  // ==================== CRUD 操作 ====================

  /// 添加条目
  Future<String> addEntry(VaultEntry entry) async {
    _entries.add(entry);
    return entry.uuid;
  }

  /// 更新条目
  Future<void> updateEntry(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.uuid == entry.uuid);
    if (index != -1) {
      _entries[index] = entry;
    }
  }

  /// 删除条目（软删除）
  Future<void> deleteEntry(String uuid) async {
    _entries.removeWhere((e) => e.uuid == uuid);
  }

  /// 永久删除条目
  Future<void> permanentlyDeleteEntry(String uuid) async {
    _entries.removeWhere((e) => e.uuid == uuid);
  }

  // ==================== 查询操作 ====================

  /// 获取所有条目
  List<VaultEntry> getAllEntries() {
    return List.unmodifiable(_entries);
  }

  /// 根据 UUID 获取条目
  VaultEntry? getEntryByUuid(String uuid) {
    try {
      return _entries.firstWhere((e) => e.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  /// 根据类型获取条目
  List<VaultEntry> getEntriesByType(EntryType type) {
    return _entries.where((e) => e.type == type).toList();
  }

  /// 搜索条目
  List<VaultEntry> searchEntries(String query) {
    final lowerQuery = query.toLowerCase();
    return _entries.where((e) {
      return e.title.toLowerCase().contains(lowerQuery) ||
          e.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // ==================== 收藏操作 ====================

  /// 获取收藏条目
  List<VaultEntry> getFavoriteEntries() {
    return _entries.where((e) => e.isFavorite).toList();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String uuid) async {
    final index = _entries.indexWhere((e) => e.uuid == uuid);
    if (index != -1) {
      _entries[index].isFavorite = !_entries[index].isFavorite;
    }
  }

  // ==================== 标签操作 ====================

  /// 获取所有标签
  List<String> getAllTags() {
    final tags = <String>{};
    for (final entry in _entries) {
      tags.addAll(entry.tags);
    }
    return tags.toList();
  }

  /// 根据标签获取条目
  List<VaultEntry> getEntriesByTag(String tag) {
    return _entries.where((e) => e.tags.contains(tag)).toList();
  }

  // ==================== 文件夹操作 ====================

  /// 获取所有文件夹
  List<Folder> getAllFolders() {
    return List.unmodifiable(_folders);
  }

  /// 添加文件夹
  Future<void> addFolder(Folder folder) async {
    _folders.add(folder);
  }

  /// 更新文件夹
  Future<void> updateFolder(Folder folder) async {
    final index = _folders.indexWhere((f) => f.uuid == folder.uuid);
    if (index != -1) {
      _folders[index] = folder;
    }
  }

  /// 删除文件夹
  Future<void> deleteFolder(String uuid) async {
    _folders.removeWhere((f) => f.uuid == uuid);
  }

  /// 根据文件夹获取条目
  List<VaultEntry> getEntriesByFolder(String folderUuid) {
    return _entries.where((e) => e.folderId == folderUuid).toList();
  }

  // ==================== 数据管理 ====================

  /// 清除所有数据
  Future<void> clearAll() async {
    _entries.clear();
    _folders.clear();
  }

  /// 导出所有数据
  Map<String, dynamic> exportAll() {
    return {
      'entries': _entries.map((e) => e.toJson()).toList(),
      'folders': _folders.map((f) => f.toJson()).toList(),
    };
  }

  /// 导入数据
  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['entries'] is List) {
      _entries.clear();
      for (final entryData in data['entries'] as List) {
        final entry = VaultEntry.fromJson(entryData as Map<String, dynamic>);
        _entries.add(entry);
      }
    }
    if (data['folders'] is List) {
      _folders.clear();
      for (final folderData in data['folders'] as List) {
        final folder = Folder.fromJson(folderData as Map<String, dynamic>);
        _folders.add(folder);
      }
    }
  }
}
