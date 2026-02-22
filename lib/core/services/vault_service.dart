import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../crypto/services/crypto_service.dart';
import '../models/vault_entry.dart';

/// 保险库服务
///
/// 负责加密存储和管理保险库条目
/// 使用单例模式确保全局只有一个实例
///
/// 参考文档: wiki/03-模块设计/保险库模块.md
class VaultService {
  static const _keyVaultData = 'vault_data';

  static VaultService? _instance;

  final FlutterSecureStorage _secureStorage;
  Uint8List? _encryptionKey;

  List<VaultEntry> _entries = [];

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

  void setEncryptionKey(Uint8List key) {
    _encryptionKey = key;
  }

  Future<void> loadVault() async {
    if (_encryptionKey == null) {
      throw VaultException('Encryption key not set');
    }

    final encryptedData = await _secureStorage.read(key: _keyVaultData);
    if (encryptedData == null || encryptedData.isEmpty) {
      _entries = [];
      return;
    }

    try {
      final data = jsonDecode(encryptedData) as Map<String, dynamic>;
      final entriesJson = data['entries'] as List<dynamic>;

      _entries = entriesJson.map((e) {
        final entry = _entryFromJson(e as Map<String, dynamic>);
        return _decryptEntry(entry);
      }).toList();
    } catch (e) {
      _entries = [];
    }
  }

  Future<void> saveVault() async {
    if (_encryptionKey == null) {
      throw VaultException('Encryption key not set');
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

  /// 根据类型将 JSON 转换为对应的条目类型
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

    final encrypted = entry.toJson();

    // 加密登录凭证字段
    if (entry is LoginEntry) {
      if (entry.password != null && entry.password!.isNotEmpty) {
        encrypted['passwordEncrypted'] = CryptoService.encrypt(entry.password!, _encryptionKey!).toJson();
      }
      if (entry.totpSecret != null && entry.totpSecret!.isNotEmpty) {
        encrypted['totpSecretEncrypted'] = CryptoService.encrypt(entry.totpSecret!, _encryptionKey!).toJson();
      }
      if (entry.notes != null && entry.notes!.isNotEmpty) {
        encrypted['notesEncrypted'] = CryptoService.encrypt(entry.notes!, _encryptionKey!).toJson();
      }
      if (entry.username != null && entry.username!.isNotEmpty) {
        encrypted['usernameEncrypted'] = CryptoService.encrypt(entry.username!, _encryptionKey!).toJson();
      }
      if (entry.email != null && entry.email!.isNotEmpty) {
        encrypted['emailEncrypted'] = CryptoService.encrypt(entry.email!, _encryptionKey!).toJson();
      }
    }
    // 加密银行卡字段
    else if (entry is BankCardEntry) {
      if (entry.cardNumber != null && entry.cardNumber!.isNotEmpty) {
        encrypted['cardNumberEncrypted'] = CryptoService.encrypt(entry.cardNumber!, _encryptionKey!).toJson();
      }
      if (entry.cvv != null && entry.cvv!.isNotEmpty) {
        encrypted['cvvEncrypted'] = CryptoService.encrypt(entry.cvv!, _encryptionKey!).toJson();
      }
    }
    // 加密安全笔记字段
    else if (entry is SecureNoteEntry) {
      if (entry.content != null && entry.content!.isNotEmpty) {
        encrypted['noteContentEncrypted'] = CryptoService.encrypt(entry.content!, _encryptionKey!).toJson();
      }
    }
    // 加密身份信息字段
    else if (entry is IdentityEntry) {
      if (entry.idNumber != null && entry.idNumber!.isNotEmpty) {
        encrypted['idNumberEncrypted'] = CryptoService.encrypt(entry.idNumber!, _encryptionKey!).toJson();
      }
      if (entry.phone != null && entry.phone!.isNotEmpty) {
        encrypted['phoneEncrypted'] = CryptoService.encrypt(entry.phone!, _encryptionKey!).toJson();
      }
      if (entry.email != null && entry.email!.isNotEmpty) {
        encrypted['emailEncrypted'] = CryptoService.encrypt(entry.email!, _encryptionKey!).toJson();
      }
      if (entry.address != null && entry.address!.isNotEmpty) {
        encrypted['addressEncrypted'] = CryptoService.encrypt(entry.address!, _encryptionKey!).toJson();
      }
    }

    return _entryFromJson(encrypted);
  }

  VaultEntry _decryptEntry(VaultEntry entry) {
    if (_encryptionKey == null) return entry;

    final data = entry.toJson();

    // 解密登录凭证字段
    if (entry is LoginEntry) {
      if (data['passwordEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['passwordEncrypted'] as Map<String, dynamic>);
        data['password'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['totpSecretEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['totpSecretEncrypted'] as Map<String, dynamic>);
        data['totpSecret'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['notesEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['notesEncrypted'] as Map<String, dynamic>);
        data['notes'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['usernameEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['usernameEncrypted'] as Map<String, dynamic>);
        data['username'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['emailEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['emailEncrypted'] as Map<String, dynamic>);
        data['email'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }
    // 解密银行卡字段
    else if (entry is BankCardEntry) {
      if (data['cardNumberEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['cardNumberEncrypted'] as Map<String, dynamic>);
        data['cardNumber'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['cvvEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['cvvEncrypted'] as Map<String, dynamic>);
        data['cvv'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }
    // 解密安全笔记字段
    else if (entry is SecureNoteEntry) {
      if (data['noteContentEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['noteContentEncrypted'] as Map<String, dynamic>);
        data['content'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }
    // 解密身份信息字段
    else if (entry is IdentityEntry) {
      if (data['idNumberEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['idNumberEncrypted'] as Map<String, dynamic>);
        data['idNumber'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['phoneEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['phoneEncrypted'] as Map<String, dynamic>);
        data['phone'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['emailEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['emailEncrypted'] as Map<String, dynamic>);
        data['email'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['addressEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['addressEncrypted'] as Map<String, dynamic>);
        data['address'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }

    return _entryFromJson(data);
  }

  Future<String> addEntry(VaultEntry entry) async {
    entry.touch();
    _entries.add(entry);
    await saveVault();
    return entry.uuid;
  }

  Future<void> updateEntry(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.uuid == entry.uuid);
    if (index == -1) {
      throw VaultException('Entry not found');
    }

    entry.touch();
    _entries[index] = entry;
    await saveVault();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.uuid == id);
    await saveVault();
  }

  Future<VaultEntry?> getEntry(String id) async {
    try {
      return _entries.firstWhere((e) => e.uuid == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<VaultEntry>> getAllEntries() async {
    return List.unmodifiable(_entries);
  }

  Future<List<VaultEntry>> getEntriesByType(EntryType type) async {
    return _entries.where((e) => e.type == type).toList();
  }

  /// 搜索条目
  ///
  /// 支持多字段搜索：标题、用户名、邮箱、URL、标签
  /// 对于加密字段，需要解密后搜索
  Future<List<VaultEntry>> searchEntries(String query) async {
    if (query.isEmpty) return getAllEntries();

    final lowerQuery = query.toLowerCase();
    final results = <VaultEntry>[];

    for (final entry in _entries) {
      // 1. 搜索标题（非加密字段）
      if (entry.title.toLowerCase().contains(lowerQuery)) {
        results.add(entry);
        continue;
      }

      // 2. 搜索标签（非加密字段）
      if (entry.tags.any((t) => t.toLowerCase().contains(lowerQuery))) {
        results.add(entry);
        continue;
      }

      // 3. 搜索登录凭证字段（加密字段需解密）
      if (entry is LoginEntry) {
        if (await _searchLoginEntry(entry, lowerQuery)) {
          results.add(entry);
          continue;
        }
      }

      // 4. 搜索银行卡字段（加密字段需解密）
      if (entry is BankCardEntry) {
        if (await _searchBankCardEntry(entry, lowerQuery)) {
          results.add(entry);
          continue;
        }
      }

      // 5. 搜索安全笔记字段（加密字段需解密）
      if (entry is SecureNoteEntry) {
        if (await _searchSecureNoteEntry(entry, lowerQuery)) {
          results.add(entry);
          continue;
        }
      }

      // 6. 搜索身份信息字段（加密字段需解密）
      if (entry is IdentityEntry) {
        if (await _searchIdentityEntry(entry, lowerQuery)) {
          results.add(entry);
          continue;
        }
      }
    }

    return results;
  }

  /// 搜索登录凭证条目
  Future<bool> _searchLoginEntry(LoginEntry entry, String lowerQuery) async {
    // 搜索用户名（加密存储）
    if (entry.username != null && entry.username!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // 搜索邮箱（加密存储）
    if (entry.email != null && entry.email!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // 搜索 URL（非加密）
    if (entry.url != null && entry.url!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // 搜索备注（加密存储）
    if (entry.notes != null && entry.notes!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    return false;
  }

  /// 搜索银行卡条目
  Future<bool> _searchBankCardEntry(BankCardEntry entry, String lowerQuery) async {
    // 搜索持卡人姓名（非加密）
    if (entry.cardHolderName != null && entry.cardHolderName!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // 搜索银行名称（非加密）
    if (entry.bankName != null && entry.bankName!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    return false;
  }

  /// 搜索安全笔记条目
  Future<bool> _searchSecureNoteEntry(SecureNoteEntry entry, String lowerQuery) async {
    // 搜索内容（加密存储）
    if (entry.content != null && entry.content!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    return false;
  }

  /// 搜索身份信息条目
  Future<bool> _searchIdentityEntry(IdentityEntry entry, String lowerQuery) async {
    // 搜索姓名（非加密）
    if (entry.firstName != null && entry.firstName!.toLowerCase().contains(lowerQuery)) {
      return true;
    }
    if (entry.lastName != null && entry.lastName!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // 搜索地址（加密存储）
    if (entry.address != null && entry.address!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    return false;
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

class VaultException implements Exception {
  final String message;
  VaultException(this.message);

  @override
  String toString() => message;
}
