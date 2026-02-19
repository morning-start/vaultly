import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../crypto/services/crypto_service.dart';
import '../models/vault_entry.dart';

class VaultService {
  static const _keyVaultData = 'vault_data';
  
  final FlutterSecureStorage _secureStorage;
  Uint8List? _encryptionKey;
  
  List<VaultEntry> _entries = [];

  VaultService({
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage();

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

    if (entry is LoginEntry) {
      if (entry.password != null && entry.password!.isNotEmpty) {
        encrypted['password'] = CryptoService.encrypt(entry.password!, _encryptionKey!).toJson();
      }
      if (entry.totpSecret != null && entry.totpSecret!.isNotEmpty) {
        encrypted['totpSecret'] = CryptoService.encrypt(entry.totpSecret!, _encryptionKey!).toJson();
      }
      if (entry.notes != null && entry.notes!.isNotEmpty) {
        encrypted['notes'] = CryptoService.encrypt(entry.notes!, _encryptionKey!).toJson();
      }
    } else if (entry is BankCardEntry) {
      if (entry.cardNumber != null && entry.cardNumber!.isNotEmpty) {
        encrypted['cardNumber'] = CryptoService.encrypt(entry.cardNumber!, _encryptionKey!).toJson();
      }
      if (entry.cvv != null && entry.cvv!.isNotEmpty) {
        encrypted['cvv'] = CryptoService.encrypt(entry.cvv!, _encryptionKey!).toJson();
      }
    } else if (entry is SecureNoteEntry) {
      if (entry.content != null && entry.content!.isNotEmpty) {
        encrypted['content'] = CryptoService.encrypt(entry.content!, _encryptionKey!).toJson();
      }
    } else if (entry is IdentityEntry) {
      if (entry.idNumber != null && entry.idNumber!.isNotEmpty) {
        encrypted['idNumber'] = CryptoService.encrypt(entry.idNumber!, _encryptionKey!).toJson();
      }
    }

    return VaultEntry.fromJson(encrypted);
  }

  VaultEntry _decryptEntry(VaultEntry entry) {
    if (_encryptionKey == null) return entry;

    final data = entry.toJson();

    if (entry is LoginEntry) {
      if (data['password'] is Map) {
        final encrypted = EncryptedData.fromJson(data['password'] as Map<String, dynamic>);
        data['password'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['totpSecret'] is Map) {
        final encrypted = EncryptedData.fromJson(data['totpSecret'] as Map<String, dynamic>);
        data['totpSecret'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['notes'] is Map) {
        final encrypted = EncryptedData.fromJson(data['notes'] as Map<String, dynamic>);
        data['notes'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    } else if (entry is BankCardEntry) {
      if (data['cardNumber'] is Map) {
        final encrypted = EncryptedData.fromJson(data['cardNumber'] as Map<String, dynamic>);
        data['cardNumber'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
      if (data['cvv'] is Map) {
        final encrypted = EncryptedData.fromJson(data['cvv'] as Map<String, dynamic>);
        data['cvv'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    } else if (entry is SecureNoteEntry) {
      if (data['content'] is Map) {
        final encrypted = EncryptedData.fromJson(data['content'] as Map<String, dynamic>);
        data['content'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    } else if (entry is IdentityEntry) {
      if (data['idNumber'] is Map) {
        final encrypted = EncryptedData.fromJson(data['idNumber'] as Map<String, dynamic>);
        data['idNumber'] = CryptoService.decrypt(encrypted, _encryptionKey!);
      }
    }

    return VaultEntry.fromJson(data);
  }

  Future<String> addEntry(VaultEntry entry) async {
    final now = DateTime.now();
    final newEntry = VaultEntry(
      id: '${now.millisecondsSinceEpoch}',
      title: entry.title,
      createdAt: now,
      updatedAt: now,
      type: entry.type,
      customFields: entry.customFields,
      tags: entry.tags,
      isFavorite: entry.isFavorite,
      folderId: entry.folderId,
    );
    
    _entries.add(newEntry);
    await saveVault();
    return newEntry.id;
  }

  Future<void> updateEntry(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw VaultException('Entry not found');
    }
    
    entry.updatedAt = DateTime.now();
    _entries[index] = entry;
    await saveVault();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await saveVault();
  }

  VaultEntry? getEntry(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
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

  Future<void> toggleFavorite(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1) {
      _entries[index].isFavorite = !_entries[index].isFavorite;
      await saveVault();
    }
  }

  Future<void> addTag(String entryId, String tag) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      if (!_entries[index].tags.contains(tag)) {
        _entries[index].tags.add(tag);
        await saveVault();
      }
    }
  }

  Future<void> removeTag(String entryId, String tag) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
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
