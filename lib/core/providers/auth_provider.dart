import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/services/auth_service.dart';
import '../crypto/services/crypto_service.dart';
import '../services/biometric_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final biometricService = ref.watch(biometricServiceProvider);
  return AuthService(biometricService: biometricService);
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// 保险库解锁状态。
///
/// 集中保存认证结果、主密码是否已设置以及生物识别能力探测结果，
/// 供路由守卫和页面层统一消费。
final isVaultUnlockedProvider = StateProvider<bool>((ref) => false);

class AuthState {
  final bool isUnlocked;
  final bool isPasswordSet;
  final bool isLoading;
  final String? error;

  // 生物识别状态
  /// 生物识别相关状态集中存放，便于在设置页和解锁页展示一致的能力信息。
  final bool biometricAvailable; // 用户是否在应用内启用了生物识别
  final bool deviceSupportsBiometric; // 设备硬件是否支持生物识别
  final String? biometricTypeName;
  final IconData? biometricIcon;
  final bool isAuthenticatingWithBiometric;

  AuthState({
    this.isUnlocked = false,
    this.isPasswordSet = false,
    this.isLoading = false,
    this.error,
    this.biometricAvailable = false,
    this.deviceSupportsBiometric = false,
    this.biometricTypeName,
    this.biometricIcon,
    this.isAuthenticatingWithBiometric = false,
  });

  AuthState copyWith({
    bool? isUnlocked,
    bool? isPasswordSet,
    bool? isLoading,
    String? error,
    bool? biometricAvailable,
    bool? deviceSupportsBiometric,
    String? biometricTypeName,
    IconData? biometricIcon,
    bool? isAuthenticatingWithBiometric,
    bool clearError = false,
  }) {
    return AuthState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isPasswordSet: isPasswordSet ?? this.isPasswordSet,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      deviceSupportsBiometric: deviceSupportsBiometric ?? this.deviceSupportsBiometric,
      biometricTypeName: biometricTypeName ?? this.biometricTypeName,
      biometricIcon: biometricIcon ?? this.biometricIcon,
      isAuthenticatingWithBiometric: isAuthenticatingWithBiometric ?? this.isAuthenticatingWithBiometric,
    );
  }
}

/// 认证状态控制器。
///
/// 负责主密码初始化、密码解锁、生物识别解锁和锁定状态管理。
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final BiometricService _biometricService;

  AuthNotifier(this._authService, this._biometricService) : super(AuthState()) {
    _init();
  }

  /// 首次加载时探测是否已设置主密码，并同步检测设备生物识别能力。
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final isPasswordSet = await _authService.isPasswordSet();

    // 检查生物识别可用性
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
      // 生物识别检查失败不影响主流程
      state = state.copyWith(
        isPasswordSet: isPasswordSet,
        biometricAvailable: false,
        deviceSupportsBiometric: false,
        isLoading: false,
      );
    }
  }

  /// 设置主密码后同步更新状态，并重新探测可用的生物识别能力。
  Future<bool> setupPassword(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.setupMasterPassword(password);

      // 设置密码后重新检查生物识别可用性
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

  /// 使用主密码解锁保险库。
  Future<bool> unlock(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final success = await _authService.verifyMasterPassword(password);
      state = state.copyWith(
        isUnlocked: success,
        isLoading: false,
        error: success ? null : '密码错误',
      );
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 使用生物识别解锁
  /// 使用系统生物识别完成解锁。
  Future<bool> unlockWithBiometric() async {
    try {
      state = state.copyWith(
        isAuthenticatingWithBiometric: true,
        error: null,
      );

      final success = await _authService.biometricUnlock();

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

  /// 启用生物识别解锁
  ///
  /// 流程：
  /// 1. 调用系统指纹认证（OS 级认证流程）
  /// 2. 验证主密码并派生加密密钥
  /// 3. 保存密钥到安全存储
  Future<bool> enableBiometric(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final success = await _authService.enableBiometric(password);

      if (success) {
        final bioAvailability = await _authService.checkBiometricAvailability();
        final icon = await _biometricService.getBiometricIcon();
        
        state = state.copyWith(
          isLoading: false,
          biometricAvailable: true,
          deviceSupportsBiometric: true,
          biometricTypeName: bioAvailability is BiometricAvailable ? bioAvailability.biometricTypeName : '生物识别',
          biometricIcon: icon,
          error: null,
        );
      } else {
        state = state.copyWith(isLoading: false, error: '生物识别启用失败');
      }

      return success;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 禁用生物识别解锁
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

  void lock() {
    _authService.lock();
    state = state.copyWith(isUnlocked: false);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  return AuthNotifier(authService, biometricService);
});
