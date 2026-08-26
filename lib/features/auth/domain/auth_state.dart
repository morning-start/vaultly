import 'package:flutter/material.dart';

/// 显式认证状态机
///
/// 将原来三个布尔值（isLoading/isPasswordSet/isUnlocked）的组合
/// 转化为四个不可重叠的状态，消除隐式条件分支。
sealed class AuthStatus {
  const AuthStatus();

  static AuthStatus from(AuthState state) {
    if (state.isLoading) return const AuthStatus.loading();
    if (state.isUnlocked) return const AuthStatus.unlocked();
    if (state.isPasswordSet) return const AuthStatus.locked();
    return const AuthStatus.needsSetup();
  }

  const factory AuthStatus.loading() = AuthStatusLoading;
  const factory AuthStatus.unlocked() = AuthStatusUnlocked;
  const factory AuthStatus.locked() = AuthStatusLocked;
  const factory AuthStatus.needsSetup() = AuthStatusNeedsSetup;
}

class AuthStatusLoading extends AuthStatus {
  const AuthStatusLoading();
}

class AuthStatusUnlocked extends AuthStatus {
  const AuthStatusUnlocked();
}

class AuthStatusLocked extends AuthStatus {
  const AuthStatusLocked();
}

class AuthStatusNeedsSetup extends AuthStatus {
  const AuthStatusNeedsSetup();
}

class AuthState {
  final bool isUnlocked;
  final bool isPasswordSet;
  final bool isLoading;
  final String? error;

  // 生物识别状态
  final bool biometricAvailable;
  final bool deviceSupportsBiometric;
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
