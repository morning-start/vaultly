import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/biometric_service.dart';
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
  static const _keyBiometricEncryptionKey = 'biometric_encryption_key';
  static const _keyFailedAttempts = 'failed_attempts';
  static const _keyLockedUntil = 'locked_until';

  // 锁定策略
  static const int _maxAttemptsBeforeShortLock = 5;
  static const int _maxAttemptsBeforeLongLock = 10;
  static const int _shortLockDurationMinutes = 5;
  static const int _longLockDurationMinutes = 30;

  final FlutterSecureStorage _secureStorage;
  final BiometricService _biometricService;
  Uint8List? _encryptionKey;
  bool _isUnlocked = false;

  AuthService({
    FlutterSecureStorage? secureStorage,
    BiometricService? biometricService,
  })  : _secureStorage = secureStorage ?? _createSecureStorage(),
        _biometricService = biometricService ?? BiometricService();

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
    final keyMaterial = CryptoService.generateKeyMaterial(password);

    // 保存到安全存储（不保存 encryptionKey，只在启用生物识别时保存）
    await _secureStorage.write(key: _keyMasterPassword, value: keyMaterial.hash);
    await _secureStorage.write(key: _keySalt, value: keyMaterial.saltBase64);

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

    // 使用 Argon2id 派生密钥材料
    final keyMaterial = CryptoService.deriveKeyMaterial(password, salt);

    if (keyMaterial.hash == storedHash) {
      // 验证成功，重置失败计数
      await _resetFailedAttempts();
      _encryptionKey = keyMaterial.key;
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

  /// 启用生物识别解锁
  ///
  /// 流程：
  /// 1. 调用系统生物识别认证（使用 OS 级认证流程）
  /// 2. 系统认证通过后，验证主密码并派生加密密钥
  /// 3. 将加密密钥保存到安全存储，用于后续生物识别解锁
  /// 返回是否启用成功
  Future<bool> enableBiometric(String password) async {
    // 检查是否已设置密码
    final isPasswordSet = await this.isPasswordSet();
    if (!isPasswordSet) {
      throw AuthException('请先设置主密码');
    }

    // 1. 调用系统生物识别认证（这是系统认证流程，弹系统指纹对话框）
    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason: '启用生物识别解锁',
      );

      if (!isAuthenticated) {
        return false;
      }
    } on BiometricException catch (e) {
      throw AuthException(e.message);
    }

    // 2. 系统认证通过后，验证主密码并派生加密密钥
    // 直接派生密钥比对，不使用 verifyMasterPassword（避免解锁副作用）
    final saltBase64 = await _secureStorage.read(key: _keySalt);
    final storedHash = await _secureStorage.read(key: _keyMasterPassword);
    if (saltBase64 == null || storedHash == null) {
      throw AuthException('密钥数据不存在，请先设置主密码');
    }

    final salt = base64Decode(saltBase64);
    final keyMaterial = CryptoService.deriveKeyMaterial(password, salt);

    if (keyMaterial.hash != storedHash) {
      throw AuthException('主密码错误');
    }

    // 3. 保存加密密钥到安全存储
    await _secureStorage.write(
      key: _keyBiometricEncryptionKey,
      value: base64Encode(keyMaterial.key),
    );

    // 同时设置内存状态
    _encryptionKey = keyMaterial.key;
    _isUnlocked = true;

    return true;
  }

  /// 禁用生物识别解锁
  ///
  /// 从安全存储中删除加密密钥
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _keyBiometricEncryptionKey);
  }

  /// 检查用户是否已启用生物识别解锁
  Future<bool> isBiometricEnabledByUser() async {
    final key = await _secureStorage.read(key: _keyBiometricEncryptionKey);
    return key != null && key.isNotEmpty;
  }

  /// 使用生物识别解锁
  ///
  /// 流程：
  /// 1. 检查密码是否已设置（必须先设置主密码）
  /// 2. 执行生物识别认证
  /// 3. 认证成功后，从安全存储恢复 encryptionKey
  Future<bool> biometricUnlock() async {
    // 检查是否已设置密码
    final isPasswordSet = await this.isPasswordSet();
    if (!isPasswordSet) {
      throw AuthException('请先设置主密码');
    }

    // 检查是否已启用生物识别
    final isEnabled = await isBiometricEnabledByUser();
    if (!isEnabled) {
      throw AuthException('生物识别未启用');
    }

    // 检查是否被锁定
    final lockStatus = await _checkLockStatus();
    if (lockStatus.isLocked) {
      throw AuthException('账户已锁定，请在 ${lockStatus.remainingMinutes} 分钟后重试');
    }

    try {
      // 执行生物识别认证
      final isAuthenticated = await _biometricService.authenticate(
        reason: '验证身份以解锁 Vaultly 保险库',
      );

      if (!isAuthenticated) {
        return false;
      }

      // 生物识别成功，从安全存储读取 encryptionKey
      final keyBase64 = await _secureStorage.read(key: _keyBiometricEncryptionKey);
      if (keyBase64 == null || keyBase64.isEmpty) {
        throw AuthException('加密密钥不存在，需要重新设置密码');
      }

      // 恢复 encryptionKey
      _encryptionKey = base64Decode(keyBase64);
      _isUnlocked = true;

      // 重置失败计数
      await _resetFailedAttempts();

      return true;
    } on BiometricException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// 检查是否可以使用生物识别解锁
  ///
  /// 返回是否可用以及原因
  Future<BiometricAvailability> checkBiometricAvailability() async {
    try {
      // 检查密码是否已设置
      final isPasswordSet = await this.isPasswordSet();
      if (!isPasswordSet) {
        return const BiometricUnavailable(
          available: false,
          reason: '未设置主密码',
        );
      }

      // 检查设备支持情况
      final isDeviceAvailable = await _biometricService.isBiometricEnrolled();

      if (!isDeviceAvailable) {
        return const BiometricUnavailable(
          available: false,
          reason: '设备不支持或未注册生物识别',
        );
      }

      // 检查用户是否已启用生物识别
      final isUserEnabled = await isBiometricEnabledByUser();

      // 获取生物识别类型名称
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

  /// 修改主密码
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final success = await verifyMasterPassword(oldPassword);
    if (!success) {
      throw AuthException('当前密码错误');
    }

    // 检查是否已启用生物识别
    final wasBiometricEnabled = await isBiometricEnabledByUser();

    // 生成新密钥
    final keyMaterial = CryptoService.generateKeyMaterial(newPassword);

    await _secureStorage.write(key: _keyMasterPassword, value: keyMaterial.hash);
    await _secureStorage.write(key: _keySalt, value: keyMaterial.saltBase64);

    // 如果之前启用了生物识别，同时更新生物识别的密钥
    if (wasBiometricEnabled) {
      await _secureStorage.write(
        key: _keyBiometricEncryptionKey,
        value: keyMaterial.keyBase64,
      );
    }

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
    await _secureStorage.delete(key: _keyBiometricEncryptionKey);
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockedUntil);

    _encryptionKey = null;
    _isUnlocked = false;
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

/// 生物识别可用性状态
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
