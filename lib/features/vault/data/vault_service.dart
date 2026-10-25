import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/vault_entry.dart';
import '../domain/encryption/entry_encryption_strategy.dart';
import '../domain/encryption/login_encryption_strategy.dart';
import '../domain/encryption/bank_card_encryption_strategy.dart';
import '../domain/encryption/secure_note_encryption_strategy.dart';
import '../domain/encryption/identity_encryption_strategy.dart';
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
      // 先解密原始持久化 JSON（密文字段在这里），
      // 再按条目类型恢复具体模型，便于兼容不同字段结构。
      final entriesJson = data['entries'] as List<dynamic>;

      _entries = entriesJson
          .map((e) => _decryptPersistedJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      // 解密/解析失败时不能静默清空内存态：一旦后续 saveVault 执行，
      // 空列表会覆盖持久化数据，造成不可恢复的数据丢失。
      // 抛出异常让调用方（UI 层）感知并阻止后续写入。
      _entries = [];
      throw VaultException.decryptionFailed(e, stackTrace);
    }
  }

  /// 将当前内存中的保险库重新写回安全存储。
  ///
  /// 写入前会对敏感字段执行字段级加密，非敏感结构字段保持可读，方便导出和调试。
  Future<void> saveVault() async {
    if (_encryptionKey == null) {
      throw VaultException.keyNotSet();
    }

    // 直接使用策略返回的加密 JSON 持久化；
    // 不能再经过 entry.toJson()，否则密文字段会被丢弃。
    final entriesJson =
        _entries.map(_encryptEntry).toList();

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

  /// 加密单个条目，返回可直接持久化的 JSON（敏感字段为密文）。
  Map<String, dynamic> _encryptEntry(VaultEntry entry) {
    final strategy = _encryptionStrategies[entry.type];
    if (_encryptionKey != null && strategy != null) {
      return strategy.encryptFields(entry, _encryptionKey!);
    }
    return entry.toJson();
  }

  /// 解密持久化 JSON 并重建条目对象。
  VaultEntry _decryptPersistedJson(Map<String, dynamic> json) {
    final strategy = _encryptionStrategies[_entryFromJson(json).type];

    if (_encryptionKey != null && strategy != null) {
      // 直接解密原始持久化 JSON —— 密文字段只存在于这里。
      strategy.decryptFields(json, _encryptionKey!);
    }

    return _entryFromJson(json);
  }

  /// 新增条目并刷新持久化数据。
  ///
  /// 模型不可变：这里生成刷新时间戳后的新实例入列，调用方持有的原实例不变。
  Future<String> addEntry(VaultEntry entry) async {
    final stamped = entry.withUpdatedTimestamp();
    _entries.add(stamped);
    await saveVault();
    return stamped.id;
  }

  /// 更新已有条目并刷新持久化数据。
  Future<void> updateEntry(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw VaultException.notFound(entry.id);
    }

    _entries[index] = entry.withUpdatedTimestamp();
    await saveVault();
  }

  /// 删除指定条目并刷新持久化数据。
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await saveVault();
  }

  /// 原子替换全部条目并持久化一次。
  ///
  /// 供恢复/导入流程使用，避免逐条增删导致每条都全量写盘。
  Future<void> replaceAllEntries(List<VaultEntry> newEntries) async {
    _entries = List.of(newEntries);
    await saveVault();
  }

  /// 获取单个条目。
  Future<VaultEntry?> getEntry(String id) async {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// 获取全部条目。
  Future<List<VaultEntry>> getAllEntries() async {
    return List.unmodifiable(_entries);
  }

  /// 切换收藏状态并持久化。
  ///
  /// 条目不存在时静默忽略（与旧语义一致）。
  Future<void> toggleFavorite(String entryId) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      _entries[index] =
          _entries[index].copyWith(isFavorite: !_entries[index].isFavorite);
      await saveVault();
    }
  }
}
