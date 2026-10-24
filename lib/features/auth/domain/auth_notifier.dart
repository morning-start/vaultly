import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../data/biometric_service.dart';
import 'auth_state.dart';
import '../../../core/exceptions/app_exception.dart';

/// 密钥发布回调：认证流程解锁/改密后，把会话密钥发布给保险库。
typedef KeyPublisher = void Function(Uint8List key);

/// 密钥清除回调：锁定时通知保险库丢弃密钥。
typedef KeyRevoker = void Function();

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

  /// 当前会话的加密密钥（内存中临时保存）
  Uint8List? _encryptionKey;

  AuthNotifier(
    this._authService,
    this._biometricService, {
    this.keyPublisher,
    this.keyRevoker,
  }) : super(AuthState()) {
    _init();
  }

  /// 获取当前加密密钥
  Uint8List? get encryptionKey => _encryptionKey;

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
      _encryptionKey = await _authService.setupMasterPassword(password);
      keyPublisher?.call(_encryptionKey!);

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
      _encryptionKey = await _authService.verifyMasterPassword(password);
      final success = _encryptionKey != null;

      if (success) {
        keyPublisher?.call(_encryptionKey!);
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

      _encryptionKey = await _authService.biometricUnlock();
      final success = _encryptionKey != null;

      if (success) {
        keyPublisher?.call(_encryptionKey!);
      }

      state = state.copyWith(
        isUnlocked: success,
        isAuthenticatingWithBiometric: false,
        error: success ? null : '生物识别验证失败',
      );

      return success;
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
      _encryptionKey = await _authService.enableBiometric(password);

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
    _encryptionKey = null;
    keyRevoker?.call();
  }

  /// 修改密码
  ///
  /// 修改成功后通过 [keyPublisher] 发布新密钥，
  /// 由保险库侧执行重加密（见 VaultNotifier.rotateKey）。
  /// 否则旧密文仍以旧密钥加密，下次用新密钥解锁将无法解密，
  /// 保险库数据会静默丢失。
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      _encryptionKey = await _authService.changePassword(
        oldPassword,
        newPassword,
      );

      // 发布新密钥：保险库收到后用新密钥重加密并持久化
      keyPublisher?.call(_encryptionKey!);

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
