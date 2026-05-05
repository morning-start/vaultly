import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/services/auth_service.dart';
import '../crypto/services/crypto_service.dart';
import '../services/biometric_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final isVaultUnlockedProvider = StateProvider<bool>((ref) => false);

class AuthState {
  final bool isUnlocked;
  final bool isPasswordSet;
  final bool isLoading;
  final String? error;

  // 生物识别状态
  final bool biometricAvailable;
  final String? biometricTypeName;
  final IconData? biometricIcon;
  final bool isAuthenticatingWithBiometric;

  AuthState({
    this.isUnlocked = false,
    this.isPasswordSet = false,
    this.isLoading = false,
    this.error,
    this.biometricAvailable = false,
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
      biometricTypeName: biometricTypeName ?? this.biometricTypeName,
      biometricIcon: biometricIcon ?? this.biometricIcon,
      isAuthenticatingWithBiometric: isAuthenticatingWithBiometric ?? this.isAuthenticatingWithBiometric,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final isPasswordSet = await _authService.isPasswordSet();

    // 检查生物识别可用性
    try {
      final bioAvailability = await _authService.checkBiometricAvailability();
      if (bioAvailability.available && bioAvailability is BiometricAvailable) {
        final biometricService = BiometricService();
        final biometricIcon = await biometricService.getBiometricIcon();
        
        state = state.copyWith(
          isPasswordSet: isPasswordSet,
          biometricAvailable: true,
          biometricTypeName: bioAvailability.biometricTypeName,
          biometricIcon: biometricIcon,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isPasswordSet: isPasswordSet,
          biometricAvailable: false,
          isLoading: false,
        );
      }
    } catch (e) {
      // 生物识别检查失败不影响主流程
      state = state.copyWith(
        isPasswordSet: isPasswordSet,
        biometricAvailable: false,
        isLoading: false,
      );
    }
  }

  Future<bool> setupPassword(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.setupMasterPassword(password);

      // 设置密码后重新检查生物识别可用性
      final bioAvailability = await _authService.checkBiometricAvailability();
      
      if (bioAvailability.available && bioAvailability is BiometricAvailable) {
        final biometricService = BiometricService();
        final icon = await biometricService.getBiometricIcon();
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

  void lock() {
    _authService.lock();
    state = state.copyWith(isUnlocked: false);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
