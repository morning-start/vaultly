import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../crypto/services/crypto_service.dart';
import '../models/vault_entry.dart';

/// 保险库服务
///
/// 负责加密存储和管理保险库条目
class VaultService {
  static const _keyVaultData = 'vault_data';

  final FlutterSecureStorage _secureStorage;
  Uint8List? _encryptionKey;

  List<VaultEntry> _entries = [];

  VaultService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

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
        final entry = VaultEntry.fromJson(e as Map<String, dynamic>);
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

  VaultEntry _encryptEntry(VaultEntry entry) {
    if (_encryptionKey == null) return entry;

    final encrypted = entry.toJson();

    // 加密登录凭证字段
    if (entry.type == EntryType.login) {
      if (entry.passwordEncrypted != null && entry.passwordEncrypted!.isNotEmpty) {
        encrypted['passwordEncrypted'] = CryptoService.encrypt(entry.passwordEncrypted!, _encryptionKey!).toJson();
      }
      if (entry.totpSecretEncrypted != null && entry.totpSecretEncrypted!.isNotEmpty) {
        encrypted['totpSecretEncrypted'] = CryptoService.encrypt(entry.totpSecretEncrypted!, _encryptionKey!).toJson();
      }
      if (entry.notesEncrypted != null && entry.notesEncrypted!.isNotEmpty) {
        encrypted['notesEncrypted'] = CryptoService.encrypt(entry.notesEncrypted!, _encryptionKey!).toJson();
      }
    }
    // 加密银行卡字段
    else if (entry.type == EntryType.bankCard) {
      if (entry.cardNumberEncrypted != null && entry.cardNumberEncrypted!.isNotEmpty) {
        encrypted['cardNumberEncrypted'] = CryptoService.encrypt(entry.cardNumberEncrypted!, _encryptionKey!).toJson();
      }
      if (entry.cvvEncrypted != null && entry.cvvEncrypted!.isNotEmpty) {
        encrypted['cvvEncrypted'] = CryptoService.encrypt(entry.cvvEncrypted!, _encryptionKey!).toJson();
      }
    }
    // 加密安全笔记字段
    else if (entry.type == EntryType.secureNote) {
      if (entry.noteContentEncrypted != null && entry.noteContentEncrypted!.isNotEmpty) {
        encrypted['noteContentEncrypted'] = CryptoService.encrypt(entry.noteContentEncrypted!, _encryptionKey!).toJson();
      }
    }
    // 加密身份信息字段
    else if (entry.type == EntryType.identity) {
      if (entry.idNumberEncrypted != null && entry.idNumberEncrypted!.isNotEmpty) {
        encrypted['idNumberEncrypted'] = CryptoService.encrypt(entry.idNumberEncrypted!, _encryptionKey!).toJson();
      }
    }

    return VaultEntry.fromJson(encrypted);
  }

  VaultEntry _decryptEntry(VaultEntry entry) {
    if (_encryptionKey == null) return entry;

    final data = entry.toJson();

    // 解密登录凭证字段
    if (entry.type == EntryType.login) {
      if (data['passwordEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['passwordEncrypted'] as Map<String, dynamic>);
        data['passwordEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['totpSecretEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['totpSecretEncrypted'] as Map<String, dynamic>);
        data['totpSecretEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['notesEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['notesEncrypted'] as Map<String, dynamic>);
        data['notesEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }
    // 解密银行卡字段
    else if (entry.type == EntryType.bankCard) {
      if (data['cardNumberEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['cardNumberEncrypted'] as Map<String, dynamic>);
        data['cardNumberEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['cvvEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['cvvEncrypted'] as Map<String, dynamic>);
        data['cvvEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }
    // 解密安全笔记字段
    else if (entry.type == EntryType.secureNote) {
      if (data['noteContentEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['noteContentEncrypted'] as Map<String, dynamic>);
        data['noteContentEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }
    // 解密身份信息字段
    else if (entry.type == EntryType.identity) {
      if (data['idNumberEncrypted'] is Map) {
        final encrypted = EncryptedData.fromJson(data['idNumberEncrypted'] as Map<String, dynamic>);
        data['idNumberEncrypted'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }

    return VaultEntry.fromJson(data);
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

  Future<void> deleteEntry(String uuid) async {
    _entries.removeWhere((e) => e.uuid == uuid);
    await saveVault();
  }

  VaultEntry? getEntry(String uuid) {
    try {
      return _entries.firstWhere((e) => e.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  List<VaultEntry> getAllEntries() {
    return List.unmodifiable(_entries);
  }

  List<VaultEntry> getEntriesByType(EntryType type) {
    return _entries.where((e) => e.type == type).toList();
  }

  List<VaultEntry> searchEntries(String query) {
    if (query.isEmpty) return getAllEntries();

    final lowerQuery = query.toLowerCase();
    return _entries.where((e) {
      if (e.title.toLowerCase().contains(lowerQuery)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(lowerQuery))) return true;
      return false;
    }).toList();
  }

  List<VaultEntry> getFavorites() {
    return _entries.where((e) => e.isFavorite).toList();
  }

  Future<void> toggleFavorite(String uuid) async {
    final index = _entries.indexWhere((e) => e.uuid == uuid);
    if (index != -1) {
      _entries[index].isFavorite = !_entries[index].isFavorite;
      await saveVault();
    }
  }

  Future<void> addTag(String entryUuid, String tag) async {
    final index = _entries.indexWhere((e) => e.uuid == entryUuid);
    if (index != -1) {
      if (!_entries[index].tags.contains(tag)) {
        _entries[index].tags.add(tag);
        await saveVault();
      }
    }
  }

  Future<void> removeTag(String entryUuid, String tag) async {
    final index = _entries.indexWhere((e) => e.uuid == entryUuid);
    if (index != -1) {
      _entries[index].tags.remove(tag);
      await saveVault();
    }
  }

  List<String> getAllTags() {
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
