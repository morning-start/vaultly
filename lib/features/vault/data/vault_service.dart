import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/vault_entry.dart';
import '../domain/encryption/entry_encryption_strategy.dart';
import '../domain/encryption/login_encryption_strategy.dart';
import '../domain/encryption/bank_card_encryption_strategy.dart';
import '../domain/encryption/secure_note_encryption_strategy.dart';
import '../domain/encryption/identity_encryption_strategy.dart';
import '../domain/search/entry_search_strategy.dart';
import '../../../core/exceptions/app_exception.dart';

/// 保险库服务
///
/// 负责加密存储、读取和维护保险库条目。
/// 采用单例模式，保证加密密钥、内存态条目列表和持久化状态一致。
///
/// 参考文档: wiki/03-模块设计/保险库模块.md
class VaultService {
  static const _keyVaultData = 'vault_data';

  static VaultService? _instance;

  final FlutterSecureStorage _secureStorage;
  Uint8List? _encryptionKey;

  List<VaultEntry> _entries = [];

  // 加密策略映射
  static const _encryptionStrategies = <EntryType, EntryEncryptionStrategy>{
    EntryType.login: LoginEncryptionStrategy(),
    EntryType.bankCard: BankCardEncryptionStrategy(),
    EntryType.secureNote: SecureNoteEncryptionStrategy(),
    EntryType.identity: IdentityEncryptionStrategy(),
  };

  /// 获取单例实例
  static VaultService get instance {
    _instance ??= VaultService._internal();
    return _instance!;
  }

  /// 私有构造函数
  VaultService._internal({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 工厂构造函数 - 返回单例实例
  factory VaultService({FlutterSecureStorage? secureStorage}) {
    _instance ??= VaultService._internal(secureStorage: secureStorage);
    return _instance!;
  }

  /// 重置单例（主要用于测试）
  static void reset() {
    _instance = null;
  }

  List<VaultEntry> get entries => List.unmodifiable(_entries);

  /// 设置当前会话的加密密钥。
  ///
  /// 解锁后由认证模块注入，后续的读写、加密和解密都依赖该密钥。
  void setEncryptionKey(Uint8List key) {
    _encryptionKey = key;
  }

  /// 从安全存储加载整个保险库。
  ///
  /// 数据在存储层以 JSON 形式保存，敏感字段会被单独加密后再序列化。
  Future<void> loadVault() async {
    if (_encryptionKey == null) {
      throw VaultException.keyNotSet();
    }

    final encryptedData = await _secureStorage.read(key: _keyVaultData);
    if (encryptedData == null || encryptedData.isEmpty) {
      _entries = [];
      return;
    }

    try {
      final data = jsonDecode(encryptedData) as Map<String, dynamic>;
      // 先反序列化再按条目类型恢复具体模型，便于兼容不同字段结构。
      final entriesJson = data['entries'] as List<dynamic>;

      _entries = entriesJson.map((e) {
        final entry = _entryFromJson(e as Map<String, dynamic>);
        return _decryptEntry(entry);
      }).toList();
    } catch (e) {
      _entries = [];
    }
  }

  /// 将当前内存中的保险库重新写回安全存储。
  ///
  /// 写入前会对敏感字段执行字段级加密，非敏感结构字段保持可读，方便导出和调试。
  Future<void> saveVault() async {
    if (_encryptionKey == null) {
      throw VaultException.keyNotSet();
    }

    final entriesJson = _entries.map((e) {
      final entry = _encryptEntry(e);
      return entry.toJson();
    }).toList();

    final data = jsonEncode({
      'entries': entriesJson,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await _secureStorage.write(key: _keyVaultData, value: data);
  }

  /// 根据类型将 JSON 转换为对应的条目类型。
  VaultEntry _entryFromJson(Map<String, dynamic> json) {
    final type = EntryType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => EntryType.custom,
    );

    switch (type) {
      case EntryType.login:
        return LoginEntry.fromJson(json);
      case EntryType.bankCard:
        return BankCardEntry.fromJson(json);
      case EntryType.secureNote:
        return SecureNoteEntry.fromJson(json);
      case EntryType.identity:
        return IdentityEntry.fromJson(json);
      case EntryType.custom:
        return VaultEntry.fromJson(json);
    }
  }

  VaultEntry _encryptEntry(VaultEntry entry) {
    if (_encryptionKey == null) return entry;

    final strategy = _encryptionStrategies[entry.type];
    if (strategy != null) {
      final encrypted = strategy.encryptFields(entry, _encryptionKey!);
      return _entryFromJson(encrypted);
    }

    return entry;
  }

  VaultEntry _decryptEntry(VaultEntry entry) {
    if (_encryptionKey == null) return entry;

    final data = entry.toJson();
    final strategy = _encryptionStrategies[entry.type];

    if (strategy != null) {
      strategy.decryptFields(entry, data, _encryptionKey!);
    }

    return _entryFromJson(data);
  }

  /// 新增条目并刷新持久化数据。
  Future<String> addEntry(VaultEntry entry) async {
    entry.touch();
    _entries.add(entry);
    await saveVault();
    return entry.uuid;
  }

  /// 更新已有条目并刷新持久化数据。
  Future<void> updateEntry(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.uuid == entry.uuid);
    if (index == -1) {
      throw VaultException.notFound(entry.uuid);
    }

    entry.touch();
    _entries[index] = entry;
    await saveVault();
  }

  /// 删除指定条目并刷新持久化数据。
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.uuid == id);
    await saveVault();
  }

  /// 获取单个条目。
  Future<VaultEntry?> getEntry(String id) async {
    try {
      return _entries.firstWhere((e) => e.uuid == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取全部条目。
  Future<List<VaultEntry>> getAllEntries() async {
    return List.unmodifiable(_entries);
  }

  /// 按类型筛选条目。
  Future<List<VaultEntry>> getEntriesByType(EntryType type) async {
    return _entries.where((e) => e.type == type).toList();
  }

  /// 搜索条目
  ///
  /// 使用策略模式，根据条目类型自动选择合适的搜索策略。
  /// 支持多字段搜索：标题、用户名、邮箱、URL、标签等
  Future<List<VaultEntry>> searchEntries(String query) async {
    if (query.isEmpty) return getAllEntries();

    final lowerQuery = query.toLowerCase();
    final results = <VaultEntry>[];

    for (final entry in _entries) {
      // 先使用基础策略搜索标题和标签
      if (BasicSearchStrategy().matches(entry, lowerQuery)) {
        results.add(entry);
        continue;
      }

      // 再使用类型特定策略搜索其他字段
      final typeStrategy = SearchStrategyFactory.getStrategy(entry.type);
      if (typeStrategy.matches(entry, lowerQuery)) {
        results.add(entry);
      }
    }

    return results;
  }

  Future<List<VaultEntry>> getFavorites() async {
    return _entries.where((e) => e.isFavorite).toList();
  }

  Future<void> toggleFavorite(String entryId) async {
    final index = _entries.indexWhere((e) => e.uuid == entryId);
    if (index != -1) {
      _entries[index].isFavorite = !_entries[index].isFavorite;
      await saveVault();
    }
  }

  Future<List<VaultEntry>> getByTag(String tag) async {
    return _entries.where((e) => e.tags.contains(tag)).toList();
  }

  Future<void> addTag(String entryId, String tag) async {
    final index = _entries.indexWhere((e) => e.uuid == entryId);
    if (index != -1) {
      if (!_entries[index].tags.contains(tag)) {
        _entries[index].tags.add(tag);
        await saveVault();
      }
    }
  }

  Future<void> removeTag(String entryId, String tag) async {
    final index = _entries.indexWhere((e) => e.uuid == entryId);
    if (index != -1) {
      _entries[index].tags.remove(tag);
      await saveVault();
    }
  }

  Future<List<String>> getAllTags() async {
    final tags = <String>{};
    for (final entry in _entries) {
      tags.addAll(entry.tags);
    }
    return tags.toList()..sort();
  }
}
