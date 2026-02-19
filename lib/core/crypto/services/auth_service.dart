import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'crypto_service.dart';

class AuthService {
  static const _keyMasterPassword = 'master_password_hash';
  static const _keySalt = 'master_salt';
  static const _keyEncryptionKey = 'encryption_key';
  static const _keyBiometricEnabled = 'biometric_enabled';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  Uint8List? _encryptionKey;
  bool _isUnlocked = false;

  AuthService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  bool get isUnlocked => _isUnlocked;
  Uint8List? get encryptionKey => _encryptionKey;

  Future<bool> isPasswordSet() async {
    final hash = await _secureStorage.read(key: _keyMasterPassword);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setupMasterPassword(String password) async {
    final salt = CryptoService.generateSalt();
    final hash = CryptoService.hashPassword(password, salt);
    final key = CryptoService.deriveKey(password, salt);

    await _secureStorage.write(key: _keyMasterPassword, value: hash);
    await _secureStorage.write(key: _keySalt, value: CryptoService.generateSaltBase64());
    await _secureStorage.write(key: _keyEncryptionKey, value: key.toString());

    _encryptionKey = key;
    _isUnlocked = true;
  }

  Future<bool> verifyMasterPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _keyMasterPassword);
    final saltBase64 = await _secureStorage.read(key: _keySalt);
    
    if (storedHash == null || saltBase64 == null) {
      return false;
    }

    final salt = Uint8List.fromList(saltBase64.codeUnits);
    final hash = CryptoService.hashPassword(password, salt);

    if (hash == storedHash) {
      _encryptionKey = CryptoService.deriveKey(password, salt);
      _isUnlocked = true;
      return true;
    }
    return false;
  }

  void lock() {
    _encryptionKey = null;
    _isUnlocked = false;
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final success = await verifyMasterPassword(oldPassword);
    if (!success) {
      throw AuthException('当前密码错误');
    }

    final salt = CryptoService.generateSalt();
    final hash = CryptoService.hashPassword(newPassword, salt);
    final key = CryptoService.deriveKey(newPassword, salt);

    await _secureStorage.write(key: _keyMasterPassword, value: hash);
    await _secureStorage.write(key: _keySalt, value: CryptoService.generateSaltBase64());
    await _secureStorage.write(key: _keyEncryptionKey, value: key.toString());

    _encryptionKey = key;
  }

  Future<void> clearAllData() async {
    await _secureStorage.delete(key: _keyMasterPassword);
    await _secureStorage.delete(key: _keySalt);
    await _secureStorage.delete(key: _keyEncryptionKey);
    await _secureStorage.delete(key: _keyBiometricEnabled);
    _encryptionKey = null;
    _isUnlocked = false;
  }

  Future<bool> isBiometricAvailable() async {
    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return isAvailable && isDeviceSupported;
  }

  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    return enabled == 'true';
  }

  Future<void> enableBiometric(bool enable) async {
    await _secureStorage.write(
      key: _keyBiometricEnabled,
      value: enable.toString(),
    );
  }

  Future<bool> unlockWithBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return false;
      }

      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      final success = await _localAuth.authenticate(
        localizedReason: '请验证身份以解锁保险库',
      );

      if (success) {
        _isUnlocked = true;
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => message;
}
