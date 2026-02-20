import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'crypto_service.dart';

/// 认证服务
/// 
/// 参考文档: 
/// - wiki/03-模块设计/认证模块.md
/// - wiki/02-架构设计/安全架构.md
/// 
/// 负责用户身份验证、会话管理和安全解锁
class AuthService {
  // 存储键名
  static const _keyMasterPassword = 'master_password_hash';
  static const _keySalt = 'master_salt';
  static const _keyEncryptionKey = 'encryption_key';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyFailedAttempts = 'failed_attempts';
  static const _keyLockedUntil = 'locked_until';

  // 锁定策略
  static const int _maxAttemptsBeforeShortLock = 5;
  static const int _maxAttemptsBeforeLongLock = 10;
  static const int _shortLockDurationMinutes = 5;
  static const int _longLockDurationMinutes = 30;

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  Uint8List? _encryptionKey;
  bool _isUnlocked = false;

  AuthService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = secureStorage ?? _createSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  /// 创建配置好的安全存储实例
  static FlutterSecureStorage _createSecureStorage() {
    return const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        accountName: 'vaultly_auth',
      ),
      aOptions: AndroidOptions(),
    );
  }

  bool get isUnlocked => _isUnlocked;
  Uint8List? get encryptionKey => _encryptionKey;

  /// 检查是否已设置主密码
  Future<bool> isPasswordSet() async {
    final hash = await _secureStorage.read(key: _keyMasterPassword);
    return hash != null && hash.isNotEmpty;
  }

  /// 设置主密码
  Future<void> setupMasterPassword(String password) async {
    // 生成新的密钥材料
    final keyMaterial = await CryptoService.generateKeyMaterial(password);

    // 保存到安全存储
    await _secureStorage.write(key: _keyMasterPassword, value: keyMaterial.hash);
    await _secureStorage.write(key: _keySalt, value: keyMaterial.saltBase64);
    await _secureStorage.write(key: _keyEncryptionKey, value: keyMaterial.keyBase64);

    // 重置失败计数
    await _resetFailedAttempts();

    _encryptionKey = keyMaterial.key;
    _isUnlocked = true;
  }

  /// 验证主密码
  Future<bool> verifyMasterPassword(String password) async {
    // 检查是否被锁定
    final lockStatus = await _checkLockStatus();
    if (lockStatus.isLocked) {
      throw AuthException('账户已锁定，请在 ${lockStatus.remainingMinutes} 分钟后重试');
    }

    final storedHash = await _secureStorage.read(key: _keyMasterPassword);
    final saltBase64 = await _secureStorage.read(key: _keySalt);

    if (storedHash == null || saltBase64 == null) {
      return false;
    }

    final salt = base64Decode(saltBase64);
    final computedHash = CryptoService.hashPassword(password, salt);
    final key = CryptoService.deriveKey(password, salt);

    if (computedHash == storedHash) {
      // 验证成功，重置失败计数
      await _resetFailedAttempts();
      _encryptionKey = key;
      _isUnlocked = true;
      return true;
    } else {
      // 验证失败，增加失败计数
      await _incrementFailedAttempts();
      return false;
    }
  }

  /// 检查锁定状态
  Future<LockStatus> _checkLockStatus() async {
    final lockedUntilStr = await _secureStorage.read(key: _keyLockedUntil);
    
    if (lockedUntilStr != null) {
      final lockedUntil = DateTime.tryParse(lockedUntilStr);
      if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
        final remaining = lockedUntil.difference(DateTime.now());
        return LockStatus(
          isLocked: true,
          remainingMinutes: remaining.inMinutes + 1,
        );
      }
    }

    return LockStatus(isLocked: false);
  }

  /// 增加失败尝试次数
  Future<void> _incrementFailedAttempts() async {
    final attemptsStr = await _secureStorage.read(key: _keyFailedAttempts);
    final attempts = (int.tryParse(attemptsStr ?? '0') ?? 0) + 1;
    
    await _secureStorage.write(key: _keyFailedAttempts, value: attempts.toString());

    // 检查是否需要锁定
    if (attempts >= _maxAttemptsBeforeLongLock) {
      // 长时间锁定
      final lockedUntil = DateTime.now().add(
        const Duration(minutes: _longLockDurationMinutes),
      );
      await _secureStorage.write(key: _keyLockedUntil, value: lockedUntil.toIso8601String());
    } else if (attempts >= _maxAttemptsBeforeShortLock) {
      // 短时间锁定
      final lockedUntil = DateTime.now().add(
        const Duration(minutes: _shortLockDurationMinutes),
      );
      await _secureStorage.write(key: _keyLockedUntil, value: lockedUntil.toIso8601String());
    }
  }

  /// 重置失败尝试次数
  Future<void> _resetFailedAttempts() async {
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockedUntil);
  }

  /// 锁定会话
  void lock() {
    // 安全清除密钥
    if (_encryptionKey != null) {
      CryptoService.secureClear(_encryptionKey!);
    }
    _encryptionKey = null;
    _isUnlocked = false;
  }

  /// 修改主密码
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final success = await verifyMasterPassword(oldPassword);
    if (!success) {
      throw AuthException('当前密码错误');
    }

    // 生成新密钥
    final keyMaterial = await CryptoService.generateKeyMaterial(newPassword);

    await _secureStorage.write(key: _keyMasterPassword, value: keyMaterial.hash);
    await _secureStorage.write(key: _keySalt, value: keyMaterial.saltBase64);
    await _secureStorage.write(key: _keyEncryptionKey, value: keyMaterial.keyBase64);

    _encryptionKey = keyMaterial.key;
  }

  /// 清除所有数据
  Future<void> clearAllData() async {
    // 安全清除密钥
    if (_encryptionKey != null) {
      CryptoService.secureClear(_encryptionKey!);
    }

    await _secureStorage.delete(key: _keyMasterPassword);
    await _secureStorage.delete(key: _keySalt);
    await _secureStorage.delete(key: _keyEncryptionKey);
    await _secureStorage.delete(key: _keyBiometricEnabled);
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockedUntil);

    _encryptionKey = null;
    _isUnlocked = false;
  }

  /// 检查生物识别是否可用
  Future<bool> isBiometricAvailable() async {
    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return isAvailable && isDeviceSupported;
  }

  /// 获取可用的生物识别类型
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }

  /// 检查生物识别是否已启用
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    return enabled == 'true';
  }

  /// 启用/禁用生物识别
  Future<void> enableBiometric(bool enable) async {
    await _secureStorage.write(
      key: _keyBiometricEnabled,
      value: enable.toString(),
    );
  }

  /// 使用生物识别解锁
  Future<bool> unlockWithBiometric() async {
    try {
      // 检查是否启用生物识别
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return false;
      }

      // 检查生物识别是否可用
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      // 检查是否被锁定
      final lockStatus = await _checkLockStatus();
      if (lockStatus.isLocked) {
        throw AuthException('账户已锁定，请在 ${lockStatus.remainingMinutes} 分钟后重试');
      }

      // 执行生物识别认证 - 使用 local_auth 3.x API
      final success = await _localAuth.authenticate(
        localizedReason: '请验证身份以解锁保险库',
      );

      if (success) {
        // 从安全存储恢复加密密钥
        final keyBase64 = await _secureStorage.read(key: _keyEncryptionKey);
        if (keyBase64 != null) {
          _encryptionKey = base64Decode(keyBase64);
          _isUnlocked = true;
          await _resetFailedAttempts();
        }
      } else {
        await _incrementFailedAttempts();
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前失败尝试次数（用于调试）
  Future<int> getFailedAttempts() async {
    final attemptsStr = await _secureStorage.read(key: _keyFailedAttempts);
    return int.tryParse(attemptsStr ?? '0') ?? 0;
  }
}

/// 锁定状态
class LockStatus {
  final bool isLocked;
  final int remainingMinutes;

  LockStatus({
    required this.isLocked,
    this.remainingMinutes = 0,
  });
}

/// 认证异常
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
