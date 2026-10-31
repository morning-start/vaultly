import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'crypto_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// 认证服务 - 纯业务逻辑
///
/// 负责执行认证相关的业务逻辑，不持有状态。
/// 状态管理由 Riverpod Notifier 负责。
class AuthService {
  static const _keyMasterPassword = 'master_password_hash';
  static const _keySalt = 'master_salt';
  static const _keyKdfParams = 'master_kdf_params';
  static const _keyBiometricEncryptionKey = 'biometric_encryption_key';
  static const _keyFailedAttempts = 'failed_attempts';
  static const _keyLockedUntil = 'locked_until';

  static const int maxAttemptsBeforeShortLock = 5;
  static const int maxAttemptsBeforeLongLock = 10;
  static const int shortLockDurationMinutes = 5;
  static const int longLockDurationMinutes = 30;

  final FlutterSecureStorage _secureStorage;
  final BiometricService _biometricService;

  AuthService({
    FlutterSecureStorage? secureStorage,
    BiometricService? biometricService,
  })  : _secureStorage = secureStorage ?? _createSecureStorage(),
        _biometricService = biometricService ?? BiometricService();

  static FlutterSecureStorage _createSecureStorage() {
    return const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        accountName: 'vaultly_auth',
      ),
      aOptions: AndroidOptions(),
    );
  }

  /// 读取本机当前使用的 KDF 参数。
  ///
  /// 优先读完整的参数集；老版本安装只存了盐值，则用当前默认强度补齐。
  /// 返回 null 表示尚未设置主密码。
  Future<KdfParams?> _readKdfParams() async {
    final paramsJson = await _secureStorage.read(key: _keyKdfParams);
    if (paramsJson != null && paramsJson.isNotEmpty) {
      try {
        return KdfParams.fromJson(
          jsonDecode(paramsJson) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('AuthService: 读取 KDF 参数失败，回退到盐值 + 默认强度: $e');
      }
    }

    final saltBase64 = await _secureStorage.read(key: _keySalt);
    if (saltBase64 == null || saltBase64.isEmpty) return null;
    return CryptoService.defaultKdfParams(base64Decode(saltBase64));
  }

  Future<void> _writeKdfParams(KdfParams params) async {
    // 盐值单独保留一份，兼容老版本读取路径
    await _secureStorage.write(
      key: _keySalt,
      value: base64Encode(params.salt),
    );
    await _secureStorage.write(
      key: _keyKdfParams,
      value: jsonEncode(params.toJson()),
    );
  }

  /// 本机当前使用的 KDF 参数（写入云端备份文件头用）
  Future<KdfParams> getKdfParams() async {
    final params = await _readKdfParams();
    if (params == null) {
      throw AuthException.passwordNotSet();
    }
    return params;
  }

  /// 用「显式给定的」KDF 参数派生密钥。
  ///
  /// 读取云端备份时参数来自文件头，因此任何设备只要主密码正确，
  /// 派生出的密钥就一致——这正是跨设备恢复能成立的前提。
  Uint8List deriveVaultKey(String password, KdfParams params) {
    return CryptoService.deriveKeyWithKdfParams(password, params);
  }

  /// 检查是否已设置主密码
  Future<bool> isPasswordSet() async {
    final hash = await _secureStorage.read(key: _keyMasterPassword);
    return hash != null && hash.isNotEmpty;
  }

  /// 设置主密码
  /// 返回加密密钥供 Notifier 管理
  Future<Uint8List> setupMasterPassword(String password) async {
    final keyMaterial = CryptoService.generateKeyMaterial(password);

    await _secureStorage.write(key: _keyMasterPassword, value: keyMaterial.hash);
    await _writeKdfParams(CryptoService.defaultKdfParams(keyMaterial.salt));

    await _resetFailedAttempts();

    return keyMaterial.key;
  }

  /// 验证主密码
  /// 返回加密密钥供 Notifier 管理
  Future<Uint8List?> verifyMasterPassword(String password) async {
    final lockStatus = await checkLockStatus();
    if (lockStatus.isLocked) {
      throw AuthException.locked(lockStatus.remainingMinutes);
    }

    final storedHash = await _secureStorage.read(key: _keyMasterPassword);
    final kdfParams = await _readKdfParams();

    if (storedHash == null || kdfParams == null) {
      throw AuthException.passwordNotSet();
    }

    final computedHash = CryptoService.deriveVerificationHash(
      password,
      kdfParams.salt,
    );

    if (computedHash == storedHash) {
      await _resetFailedAttempts();
      return CryptoService.deriveKeyWithKdfParams(password, kdfParams);
    } else {
      await _incrementFailedAttempts();
      return null;
    }
  }

  /// 检查锁定状态
  Future<LockStatus> checkLockStatus() async {
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

  Future<void> _incrementFailedAttempts() async {
    final attemptsStr = await _secureStorage.read(key: _keyFailedAttempts);
    final attempts = (int.tryParse(attemptsStr ?? '0') ?? 0) + 1;

    await _secureStorage.write(key: _keyFailedAttempts, value: attempts.toString());

    if (attempts >= maxAttemptsBeforeLongLock) {
      final lockedUntil = DateTime.now().add(
        const Duration(minutes: longLockDurationMinutes),
      );
      await _secureStorage.write(key: _keyLockedUntil, value: lockedUntil.toIso8601String());
    } else if (attempts >= maxAttemptsBeforeShortLock) {
      final lockedUntil = DateTime.now().add(
        const Duration(minutes: shortLockDurationMinutes),
      );
      await _secureStorage.write(key: _keyLockedUntil, value: lockedUntil.toIso8601String());
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockedUntil);
  }

  /// 启用生物识别
  /// 返回加密密钥供 Notifier 管理
  Future<Uint8List> enableBiometric(String password) async {
    final isPasswordSet = await this.isPasswordSet();
    if (!isPasswordSet) {
      throw AuthException.passwordNotSet();
    }

    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason: '启用生物识别解锁',
      );

      if (!isAuthenticated) {
        throw AuthException.biometricFailed('认证取消');
      }
    } on BiometricException catch (e) {
      throw AuthException.biometricFailed(e.message);
    }

    final kdfParams = await _readKdfParams();
    final storedHash = await _secureStorage.read(key: _keyMasterPassword);
    if (kdfParams == null || storedHash == null) {
      throw AuthException.passwordNotSet();
    }

    if (CryptoService.deriveVerificationHash(password, kdfParams.salt) !=
        storedHash) {
      throw AuthException.invalidPassword();
    }

    final key = CryptoService.deriveKeyWithKdfParams(password, kdfParams);

    await _secureStorage.write(
      key: _keyBiometricEncryptionKey,
      value: base64Encode(key),
    );

    return key;
  }

  /// 禁用生物识别
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _keyBiometricEncryptionKey);
  }

  /// 检查是否已启用生物识别
  Future<bool> isBiometricEnabledByUser() async {
    final key = await _secureStorage.read(key: _keyBiometricEncryptionKey);
    return key != null && key.isNotEmpty;
  }

  /// 生物识别解锁
  /// 返回加密密钥供 Notifier 管理
  Future<Uint8List> biometricUnlock() async {
    final isPasswordSet = await this.isPasswordSet();
    if (!isPasswordSet) {
      throw AuthException.passwordNotSet();
    }

    final isEnabled = await isBiometricEnabledByUser();
    if (!isEnabled) {
      throw AuthException.biometricFailed('生物识别未启用');
    }

    final lockStatus = await checkLockStatus();
    if (lockStatus.isLocked) {
      throw AuthException.locked(lockStatus.remainingMinutes);
    }

    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason: '验证身份以解锁 Vaultly 保险库',
      );

      if (!isAuthenticated) {
        throw AuthException.biometricFailed();
      }

      final keyBase64 = await _secureStorage.read(key: _keyBiometricEncryptionKey);
      if (keyBase64 == null || keyBase64.isEmpty) {
        throw AuthException.biometricFailed('加密密钥不存在，需要重新设置密码');
      }

      final key = base64Decode(keyBase64);
      await _resetFailedAttempts();
      return key;
    } on BiometricException catch (e) {
      throw AuthException.biometricFailed(e.message);
    }
  }

  /// 检查生物识别可用性
  Future<BiometricAvailability> checkBiometricAvailability() async {
    try {
      final isPasswordSet = await this.isPasswordSet();
      if (!isPasswordSet) {
        return const BiometricUnavailable(
          available: false,
          reason: '未设置主密码',
        );
      }

      final isDeviceAvailable = await _biometricService.isBiometricEnrolled();

      if (!isDeviceAvailable) {
        return const BiometricUnavailable(
          available: false,
          reason: '设备不支持或未注册生物识别',
        );
      }

      final isUserEnabled = await isBiometricEnabledByUser();
      final typeName = await _biometricService.getBiometricTypeName();

      if (isUserEnabled) {
        return BiometricAvailable(
          available: true,
          biometricTypeName: typeName,
        );
      } else {
        return BiometricAvailable(
          available: false,
          biometricTypeName: typeName,
          reason: '生物识别未启用，请在设置中开启',
        );
      }
    } on Exception catch (e) {
      return BiometricUnavailable(
        available: false,
        reason: e.toString(),
      );
    }
  }

  /// 修改密码
  /// 返回新加密密钥供 Notifier 管理
  Future<Uint8List> changePassword(String oldPassword, String newPassword) async {
    final key = await verifyMasterPassword(oldPassword);
    if (key == null) {
      throw AuthException.invalidPassword();
    }

    final wasBiometricEnabled = await isBiometricEnabledByUser();
    final keyMaterial = CryptoService.generateKeyMaterial(newPassword);

    await _secureStorage.write(key: _keyMasterPassword, value: keyMaterial.hash);
    await _writeKdfParams(CryptoService.defaultKdfParams(keyMaterial.salt));

    if (wasBiometricEnabled) {
      await _secureStorage.write(
        key: _keyBiometricEncryptionKey,
        value: keyMaterial.keyBase64,
      );
    }

    return keyMaterial.key;
  }

  /// 清除所有数据
  Future<void> clearAllData() async {
    await _secureStorage.delete(key: _keyMasterPassword);
    await _secureStorage.delete(key: _keySalt);
    await _secureStorage.delete(key: _keyKdfParams);
    await _secureStorage.delete(key: _keyBiometricEncryptionKey);
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockedUntil);
  }

  /// 获取失败尝试次数
  Future<int> getFailedAttempts() async {
    final attemptsStr = await _secureStorage.read(key: _keyFailedAttempts);
    return int.tryParse(attemptsStr ?? '0') ?? 0;
  }

  /// 安全清除密钥
  void secureKey(Uint8List key) {
    CryptoService.secureClear(key);
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

/// 生物识别可用性抽象类
abstract class BiometricAvailability {
  final bool available;
  final String? reason;

  const BiometricAvailability({
    required this.available,
    this.reason,
  });
}

/// 生物识别可用
class BiometricAvailable extends BiometricAvailability {
  final String? biometricTypeName;

  const BiometricAvailable({
    required super.available,
    this.biometricTypeName,
    super.reason,
  });
}

/// 生物识别不可用
class BiometricUnavailable extends BiometricAvailability {
  const BiometricUnavailable({
    required super.available,
    required super.reason,
  });
}
