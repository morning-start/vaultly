import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../data/biometric_service.dart';
import 'package:vaultly_core/vaultly_core.dart';
import 'auth_state.dart';

/// 密钥发布回调：认证流程解锁/改密后，把会话密钥发布给保险库。
typedef KeyPublisher = void Function(Uint8List key);

/// 密钥清除回调：锁定时通知保险库丢弃密钥。
typedef KeyRevoker = void Function();

/// 密钥迁移回调：用新密钥重加密已加载的数据（**必须等待完成**）。
///
/// 不能走 fire-and-forget 的发布通道：迁移时数据必须先以旧密钥加载完，
/// 否则「用新密钥重加密」会拿空列表覆盖磁盘。
typedef KeyMigrator = Future<void> Function(Uint8List oldKey, Uint8List newKey);

/// 认证状态管理器
///
/// 负责管理认证状态、加密密钥等敏感信息。
/// 状态变更通过 AuthState 暴露给 UI。
///
/// 密钥生命周期通过回调与保险库解耦（见 [keyPublisher]/[keyRevoker]），
/// 认证模块不直接依赖 Vault 模块。
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final BiometricService _biometricService;

  /// 解锁/改密成功后发布新会话密钥
  final KeyPublisher? keyPublisher;

  /// 锁定/清除数据时回收密钥
  final KeyRevoker? keyRevoker;

  /// 本地数据密钥迁移（把数据从 masterSecret 重加密为 DEK），必须等待完成
  final KeyMigrator? keyMigrator;

  /// 只更新会话密钥缓存（不触发保险库动作）
  final void Function(Uint8List key)? keyRecacher;

  /// 当前会话的加密密钥（内存中临时保存）
  ///
  /// R2 之后这是 **DEK**（本地数据的字段级加密密钥）；
  /// DEK 迁移尚未完成时暂时等于 masterSecret。
  Uint8List? _encryptionKey;

  /// 主密码派生密钥（内存中临时保存）
  ///
  /// 用途与 [_encryptionKey] 不同：**云端备份**始终由它加密，
  /// 因此生物识别会话（没有明文主密码）也必须持有它，否则无法上传。
  Uint8List? _masterSecret;

  /// 当前会话的主密码（内存中临时保存，锁定即清除）
  ///
  /// 跨设备解密云端备份时必须重新做一次密钥派生：备份文件头里的盐值
  /// 与本机盐值不同，而 Argon2id 需要明文口令才能派生。
  /// 只保留内存副本，不落盘。
  String? _masterPassword;

  AuthNotifier(
    this._authService,
    this._biometricService, {
    this.keyPublisher,
    this.keyRevoker,
    this.keyMigrator,
    this.keyRecacher,
  }) : super(AuthState()) {
    _init();
  }

  /// 获取当前加密密钥（本地字段加密用，R2 后为 DEK）
  Uint8List? get encryptionKey => _encryptionKey;

  /// 云端备份用的密钥（主密码派生）
  ///
  /// 与 [encryptionKey] 是两把不同的密钥：备份必须能被其他设备
  /// 用同一个主密码解开，因此不能用 DEK。
  Uint8List? get backupKey => _masterSecret;

  /// 获取当前会话的主密码（仅内存态；生物识别解锁后可能为 null）
  String? get masterPassword => _masterPassword;

  /// 本机当前使用的 KDF 参数（写入云端备份文件头用）
  Future<KdfParams> currentKdfParams() => _authService.getKdfParams();

  /// 当前密钥体系指纹（判断云端备份是否由当前主密码加密）
  Future<String?> currentKeyTag() => _authService.currentKeyTag();

  /// 用指定 KDF 参数从主密码派生密钥（参数通常来自备份文件头）
  Uint8List deriveVaultKey(String password, KdfParams params) =>
      _authService.deriveVaultKey(password, params);

  /// 初始化状态
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final isPasswordSet = await _authService.isPasswordSet();

    try {
      final bioAvailability = await _authService.checkBiometricAvailability();
      final biometricIcon = await _biometricService.getBiometricIcon();

      if (bioAvailability is BiometricAvailable) {
        state = state.copyWith(
          isPasswordSet: isPasswordSet,
          biometricAvailable: bioAvailability.available,
          deviceSupportsBiometric: true,
          biometricTypeName: bioAvailability.biometricTypeName,
          biometricIcon: biometricIcon,
          isLoading: false,
        );
      } else if (bioAvailability is BiometricUnavailable) {
        state = state.copyWith(
          isPasswordSet: isPasswordSet,
          biometricAvailable: false,
          deviceSupportsBiometric: false,
          biometricTypeName: null,
          biometricIcon: null,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isPasswordSet: isPasswordSet,
        biometricAvailable: false,
        deviceSupportsBiometric: false,
        isLoading: false,
      );
    }
  }

  /// 设置主密码
  Future<bool> setupPassword(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await _authService.setupMasterPassword(password);
      _applyUnlockResult(result);
      _masterPassword = password;
      keyPublisher?.call(result.sessionKey);

      final bioAvailability = await _authService.checkBiometricAvailability();

      if (bioAvailability is BiometricAvailable) {
        final icon = await _biometricService.getBiometricIcon();
        state = state.copyWith(
          isPasswordSet: true,
          isUnlocked: true,
          isLoading: false,
          biometricAvailable: bioAvailability.available,
          biometricTypeName: bioAvailability.biometricTypeName,
          biometricIcon: icon,
        );
      } else {
        state = state.copyWith(
          isPasswordSet: true,
          isUnlocked: true,
          isLoading: false,
          biometricAvailable: false,
          biometricTypeName: null,
          biometricIcon: null,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 使用密码解锁
  Future<bool> unlock(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await _authService.verifyMasterPassword(password);
      final success = result != null;

      if (success) {
        _masterPassword = password;
        _applyUnlockResult(result);
        // 先让保险库用会话密钥加载（迁移时它是 masterSecret，数据可读）
        keyPublisher?.call(result.sessionKey);
        if (result.needsDekMigration) {
          await _migrateToDek(result.masterSecret);
        }
      }

      state = state.copyWith(
        isUnlocked: success,
        isLoading: false,
        error: success ? null : '密码错误',
      );
      return success;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 生物识别解锁
  Future<bool> unlockWithBiometric() async {
    try {
      state = state.copyWith(
        isAuthenticatingWithBiometric: true,
        error: null,
      );

      final result = await _authService.biometricUnlock();

      // 生物识别路径没有明文口令可用，跨设备解密备份时会要求改用密码解锁
      _masterPassword = null;
      _applyUnlockResult(result);
      keyPublisher?.call(result.sessionKey);
      if (result.needsDekMigration) {
        await _migrateToDek(result.masterSecret);
      }

      state = state.copyWith(
        isUnlocked: true,
        isAuthenticatingWithBiometric: false,
        error: null,
      );

      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isAuthenticatingWithBiometric: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isAuthenticatingWithBiometric: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 启用生物识别
  Future<bool> enableBiometric(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await _authService.enableBiometric(password);
      _applyUnlockResult(result);
      _masterPassword = password;

      final bioAvailability = await _authService.checkBiometricAvailability();
      final icon = await _biometricService.getBiometricIcon();

      state = state.copyWith(
        isLoading: false,
        biometricAvailable: true,
        deviceSupportsBiometric: true,
        biometricTypeName: bioAvailability is BiometricAvailable
            ? bioAvailability.biometricTypeName
            : '生物识别',
        biometricIcon: icon,
        error: null,
      );

      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 禁用生物识别
  Future<void> disableBiometric() async {
    try {
      await _authService.disableBiometric();
      state = state.copyWith(
        biometricAvailable: false,
        biometricTypeName: null,
        biometricIcon: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 锁定应用
  void lock() {
    _clearSessionKey();
    state = state.copyWith(isUnlocked: false);
  }

  void _clearSessionKey() {
    if (_encryptionKey != null) {
      _authService.secureKey(_encryptionKey!);
    }
    if (_masterSecret != null) {
      _authService.secureKey(_masterSecret!);
    }
    _encryptionKey = null;
    _masterSecret = null;
    _masterPassword = null;
    keyRevoker?.call();
  }

  /// 记录解锁结果中的两把密钥
  void _applyUnlockResult(UnlockResult result) {
    _encryptionKey = result.sessionKey;
    _masterSecret = result.masterSecret;
  }

  /// 完成 DEK 迁移：把本地数据从 masterSecret 重加密为 DEK
  ///
  /// 顺序很重要：
  /// 1. `ensureDek` 先落盘包装好的 DEK（保证 DEK 可恢复）
  /// 2. 由保险库侧「用旧密钥读、用新密钥写」完成重加密（等待完成，避免竞态）
  /// 3. 失败则删除刚写的 wrappedDek 回滚，保持旧的密钥体系——数据依然可读
  Future<void> _migrateToDek(Uint8List masterSecret) async {
    if (keyMigrator == null) {
      debugPrint('Auth: 无密钥迁移通道，本地数据继续使用 masterSecret');
      return;
    }

    final hadDek = await _authService.hasWrappedDek();

    try {
      final dek = await _authService.ensureDek(masterSecret);
      await keyMigrator!(masterSecret, dek);

      _encryptionKey = dek;
      keyRecacher?.call(dek);
      debugPrint('Auth: 本地数据已迁移到独立的数据密钥（DEK）');
    } catch (e) {
      debugPrint('Auth: DEK 迁移失败，保留原密钥体系: $e');
      if (!hadDek) {
        await _authService.clearWrappedDek();
      }
      // 会话密钥仍是 masterSecret，数据可正常读取
    }
  }

  /// 修改主密码
  ///
  /// R2 之后改密**只重新包装 DEK**，保险库数据不动，
  /// 因此这里不再需要触发全量重加密（旧的实现靠 keyPublisher 让保险库重写全部条目）。
  /// 注意：云端备份仍由主密码派生密钥加密，所以改密后 keyTag 会变，
  /// 同步页会提示「云端备份还是旧主密码加密的」，需要重新上传一次。
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await _authService.changePassword(
        oldPassword,
        newPassword,
      );
      _applyUnlockResult(result);
      _masterPassword = newPassword;

      // 尚未迁移完成时，这里补上最后一步重加密
      if (result.needsDekMigration) {
        await _migrateToDek(result.masterSecret);
      }

      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 清除所有数据
  Future<void> clearAllData() async {
    _clearSessionKey();
    await _authService.clearAllData();
    state = AuthState();
  }
}
