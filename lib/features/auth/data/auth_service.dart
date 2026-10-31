import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'package:vaultly_core/vaultly_core.dart';

/// 认证服务 - 纯业务逻辑
///
/// 负责执行认证相关的业务逻辑，不持有状态。
/// 状态管理由 Riverpod Notifier 负责。
class AuthService {
  /// 【遗留】sha256 校验哈希的存储键。
  ///
  /// 仅用于旧安装的迁移校验；迁移成功后会被删除（该值可被低成本离线爆破）。
  static const _keyLegacyVerificationHash = 'master_password_hash';

  /// 口令校验值（HKDF(masterSecret, "vaultly/auth")，base64）
  static const _keyMasterVerifier = 'master_verifier';

  /// 密钥体系指纹（备份过期检测）
  static const _keyKeyTag = 'master_key_tag';

  static const _keySalt = 'master_salt';
  static const _keyKdfParams = 'master_kdf_params';

  /// 被 KEK 包装的数据加密密钥（DEK）
  static const _keyWrappedDek = 'vault_dek_wrapped';

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

  /// 当前密钥体系的指纹（非敏感）
  ///
  /// 主密码一变，盐和密钥都会变，指纹随之改变。用它来判断
  /// 「云端那份备份还是不是当前主密码加密的」——改过主密码之后，
  /// 之前上传的备份只有旧密码能解开，需要重新上传一次。
  ///
  /// 指纹由 `HKDF(masterSecret, "vaultly/key-tag")` 派生，在解锁/设密/改密时
  /// 写入。**不能**基于落盘的校验值再哈希：校验方案一升级，基于它的指纹就会变，
  /// 会让所有设备在升级当天误报「云端备份已过期」。
  ///
  /// 读取不需要主密码，因此生物识别解锁的会话同样可用。
  Future<String?> currentKeyTag() async {
    final tag = await _secureStorage.read(key: _keyKeyTag);
    return (tag == null || tag.isEmpty) ? null : tag;
  }

  /// 写入校验值与指纹（凭证体系 v2）
  Future<void> _writeVerifier(KeyMaterial keyMaterial) async {
    await _secureStorage.write(
      key: _keyMasterVerifier,
      value: keyMaterial.authKeyBase64,
    );
    await _secureStorage.write(key: _keyKeyTag, value: keyMaterial.keyTag);
  }

  // ==================== DEK（数据加密密钥）====================

  /// 是否已有包装好的 DEK
  Future<bool> hasWrappedDek() async {
    final raw = await _secureStorage.read(key: _keyWrappedDek);
    return raw != null && raw.isNotEmpty;
  }

  /// 用 masterSecret 解包 DEK；不存在或解不开时返回 null
  Future<Uint8List?> _readDek(Uint8List masterSecret) async {
    final raw = await _secureStorage.read(key: _keyWrappedDek);
    if (raw == null || raw.isEmpty) return null;

    try {
      final wrapped = EncryptedData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return CryptoService.unwrapKey(
        wrapped,
        CryptoService.deriveWrapKey(masterSecret),
      );
    } catch (e) {
      // 解不开（包装密钥不对或数据损坏）→ 交给上层决定回退/重建
      debugPrint('AuthService: DEK 解包失败: $e');
      return null;
    }
  }

  Future<void> _writeWrappedDek(Uint8List dek, Uint8List masterSecret) async {
    final wrapped = CryptoService.wrapKey(
      dek,
      CryptoService.deriveWrapKey(masterSecret),
    );
    await _secureStorage.write(
      key: _keyWrappedDek,
      value: jsonEncode(wrapped.toJson()),
    );
  }

  /// 确保 DEK 存在并已用 [masterSecret] 包装，返回该 DEK
  ///
  /// 幂等：已存在且能解包时直接复用（不会因为重复调用而换密钥）。
  Future<Uint8List> ensureDek(Uint8List masterSecret) async {
    final existing = await _readDek(masterSecret);
    if (existing != null) return existing;

    final dek = CryptoService.generateDek();
    await _writeWrappedDek(dek, masterSecret);
    return dek;
  }

  /// 清除包装好的 DEK（迁移失败时回滚，恢复「数据由 masterSecret 加密」的状态）
  Future<void> clearWrappedDek() async {
    await _secureStorage.delete(key: _keyWrappedDek);
  }

  /// 校验主密码并返回密钥材料；密码错误返回 null。
  ///
  /// 双轨校验：
  /// - 已有 v2 校验值 → 用 HKDF 派生的 authKey 定长时间比较
  /// - 只有旧版 sha256 值（升级前的安装）→ 校验通过后**就地升级**：
  ///   写入 v2 校验值与指纹，并删除可被离线爆破的 sha256 值
  Future<KeyMaterial?> _verifyPassword(String password) async {
    final kdfParams = await _readKdfParams();
    if (kdfParams == null) {
      throw AuthException.passwordNotSet();
    }

    final keyMaterial = CryptoService.deriveKeyMaterial(
      password,
      kdfParams.salt,
    );

    final storedVerifier = await _secureStorage.read(key: _keyMasterVerifier);
    final legacyHash = await _secureStorage.read(
      key: _keyLegacyVerificationHash,
    );

    if ((storedVerifier == null || storedVerifier.isEmpty) &&
        (legacyHash == null || legacyHash.isEmpty)) {
      throw AuthException.passwordNotSet();
    }

    if (storedVerifier != null && storedVerifier.isNotEmpty) {
      final matches = CryptoService.constantTimeEquals(
        keyMaterial.authKey,
        base64Decode(storedVerifier),
      );
      if (!matches) return null;
      await _secureStorage.write(key: _keyKeyTag, value: keyMaterial.keyTag);
      return keyMaterial;
    }

    // —— 旧格式迁移路径 ——
    if (keyMaterial.hash != legacyHash) return null;

    await _writeVerifier(keyMaterial);
    await _secureStorage.delete(key: _keyLegacyVerificationHash);
    debugPrint(
      'AuthService: 校验值已升级为 Argon2id + HKDF 派生（sha256 值已删除）',
    );
    return keyMaterial;
  }

  /// 检查是否已设置主密码
  Future<bool> isPasswordSet() async {
    final verifier = await _secureStorage.read(key: _keyMasterVerifier);
    if (verifier != null && verifier.isNotEmpty) return true;

    final legacy = await _secureStorage.read(key: _keyLegacyVerificationHash);
    return legacy != null && legacy.isNotEmpty;
  }

  /// 设置主密码
  ///
  /// 新安装直接生成随机 DEK 并用主密码包装：数据从一开始就由 DEK 加密，
  /// 因此永不需要「迁移」。返回解锁结果供 Notifier 管理。
  Future<UnlockResult> setupMasterPassword(String password) async {
    final keyMaterial = CryptoService.generateKeyMaterial(password);

    // 新安装只写 v2 校验值，不再产生可被离线爆破的 sha256 值
    await _writeVerifier(keyMaterial);
    await _writeKdfParams(CryptoService.defaultKdfParams(keyMaterial.salt));

    final dek = CryptoService.generateDek();
    await _writeWrappedDek(dek, keyMaterial.key);

    await _resetFailedAttempts();

    return UnlockResult(
      sessionKey: dek,
      masterSecret: keyMaterial.key,
      needsDekMigration: false,
    );
  }

  /// 验证主密码
  ///
  /// 返回解锁结果（含会话密钥与主密码派生密钥），密码错误返回 null。
  /// 此时**不**创建 DEK——若本机还没有 DEK，说明数据仍由 masterSecret 加密，
  /// 该标记为 [UnlockResult.needsDekMigration]，由上层完成重加密后再切换。
  Future<UnlockResult?> verifyMasterPassword(String password) async {
    final lockStatus = await checkLockStatus();
    if (lockStatus.isLocked) {
      throw AuthException.locked(lockStatus.remainingMinutes);
    }

    final keyMaterial = await _verifyPassword(password);

    if (keyMaterial != null) {
      await _resetFailedAttempts();
      final dek = await _readDek(keyMaterial.key);
      final needsMigration = dek == null;

      return UnlockResult(
        // 还没有 DEK 时，数据仍是 masterSecret 加密的，会话密钥先用它
        sessionKey: dek ?? keyMaterial.key,
        masterSecret: keyMaterial.key,
        needsDekMigration: needsMigration,
      );
    }

    await _incrementFailedAttempts();
    return null;
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
  /// 返回解锁结果供 Notifier 管理
  Future<UnlockResult> enableBiometric(String password) async {
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

    final keyMaterial = await _verifyPassword(password);
    if (keyMaterial == null) {
      throw AuthException.invalidPassword();
    }

    // 存的是 masterSecret：它既能解包 DEK（本地数据），
    // 又能在生物识别会话里继续加密云端备份（见 ADR-006 R2 的 F2 约束）
    await _secureStorage.write(
      key: _keyBiometricEncryptionKey,
      value: base64Encode(keyMaterial.key),
    );

    final dek = await _readDek(keyMaterial.key);

    return UnlockResult(
      sessionKey: dek ?? keyMaterial.key,
      masterSecret: keyMaterial.key,
      needsDekMigration: dek == null,
    );
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
  ///
  /// 取出包装用的 masterSecret → 解包 DEK 作为会话密钥。
  /// masterSecret 同时回传给上层：生物识别会话没有明文主密码，
  /// 但**上传云端备份必须仍可用**（用 masterSecret 加密），
  /// 因此这里一并返回，见 ADR-006 R2 的能力矩阵。
  Future<UnlockResult> biometricUnlock() async {
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

      final masterSecret = base64Decode(keyBase64);
      final dek = await _readDek(masterSecret);

      if (dek == null) {
        // 有 DEK 却解不开 → 包装密钥不匹配（例如改密后本项未更新）
        if (await hasWrappedDek()) {
          throw AuthException.biometricFailed('密钥已失效，请用主密码解锁一次');
        }

        // 本机还没有 DEK（升级前的老安装）：数据仍由 masterSecret 加密，
        // 先照常解锁，由上层完成到 DEK 的迁移
        await _resetFailedAttempts();
        return UnlockResult(
          sessionKey: masterSecret,
          masterSecret: masterSecret,
          needsDekMigration: true,
        );
      }

      await _resetFailedAttempts();
      return UnlockResult(
        sessionKey: dek,
        masterSecret: masterSecret,
        needsDekMigration: false,
      );
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

  /// 修改主密码
  ///
  /// **只重新包装 DEK**，不重加密保险库数据——这是 R2 的核心收益：
  /// 改密从「全量重写所有条目」变成一次 AES-GCM 包装（毫秒级）。
  /// 会话密钥（DEK）保持不变，因此调用方无需重载/重加密数据。
  ///
  /// 例外：本机还没有 DEK（尚未完成迁移）时，这里会新建一个并置位
  /// [UnlockResult.needsDekMigration]，由上层完成最后一步重加密。
  Future<UnlockResult> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final verified = await verifyMasterPassword(oldPassword);
    if (verified == null) {
      throw AuthException.invalidPassword();
    }

    final wasBiometricEnabled = await isBiometricEnabledByUser();
    final keyMaterial = CryptoService.generateKeyMaterial(newPassword);

    // 复用已有 DEK；没有（迁移未完成）则新建
    final dek = await _readDek(verified.masterSecret) ??
        CryptoService.generateDek();
    await _writeWrappedDek(dek, keyMaterial.key);

    await _writeVerifier(keyMaterial);
    await _writeKdfParams(CryptoService.defaultKdfParams(keyMaterial.salt));
    // 改密后旧格式校验值已无意义，顺手清掉
    await _secureStorage.delete(key: _keyLegacyVerificationHash);

    if (wasBiometricEnabled) {
      // 生物识别项存的是 masterSecret，必须跟着换成新密码派生的
      await _secureStorage.write(
        key: _keyBiometricEncryptionKey,
        value: base64Encode(keyMaterial.key),
      );
    }

    return UnlockResult(
      sessionKey: dek,
      masterSecret: keyMaterial.key,
      needsDekMigration: verified.needsDekMigration,
    );
  }

  /// 清除所有数据
  Future<void> clearAllData() async {
    await _secureStorage.delete(key: _keyLegacyVerificationHash);
    await _secureStorage.delete(key: _keyMasterVerifier);
    await _secureStorage.delete(key: _keyKeyTag);
    await _secureStorage.delete(key: _keySalt);
    await _secureStorage.delete(key: _keyKdfParams);
    await _secureStorage.delete(key: _keyWrappedDek);
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

/// 解锁/改密的结果
///
/// R2 之后本机有**两把**用途不同的密钥，必须分开传递：
/// - [sessionKey]：字段级加密用（DEK）。迁移未完成时暂时等于 masterSecret
/// - [masterSecret]：主密码派生密钥，用于加密云端备份
///   （生物识别会话没有明文主密码，但上传必须仍可用，所以由这里回传）
class UnlockResult {
  final Uint8List sessionKey;
  final Uint8List masterSecret;

  /// 本地数据仍由 masterSecret 加密，需要上层用新 DEK 重加密一次
  final bool needsDekMigration;

  const UnlockResult({
    required this.sessionKey,
    required this.masterSecret,
    this.needsDekMigration = false,
  });
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
