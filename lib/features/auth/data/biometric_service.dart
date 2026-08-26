import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService({
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> isBiometricEnrolled() async {
    try {
      final deviceSupported = await isDeviceSupported();
      if (!deviceSupported) return false;

      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  @Deprecated('Use isBiometricEnrolled instead')
  Future<bool> isBiometricEnabled() async {
    return isBiometricEnrolled();
  }

  @Deprecated('Use isDeviceSupported instead')
  Future<bool> isBiometricAvailable() async {
    return isDeviceSupported();
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on LocalAuthException {
      return [];
    }
  }

  Future<String> getBiometricTypeName() async {
    final types = await getAvailableBiometrics();

    if (types.isEmpty) return '生物识别';

    if (Platform.isIOS) {
      if (types.contains(BiometricType.face)) {
        return 'Face ID';
      }
      if (types.contains(BiometricType.fingerprint)) {
        return 'Touch ID';
      }
    }

    if (Platform.isAndroid) {
      if (types.contains(BiometricType.fingerprint)) {
        return '指纹';
      }
      if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
        return '指纹';
      }
    }

    return '生物识别';
  }

  Future<IconData> getBiometricIcon() async {
    final types = await getAvailableBiometrics();

    if (Platform.isIOS) {
      if (types.contains(BiometricType.face)) {
        return Icons.face_retouching_natural_outlined;
      }
      if (types.contains(BiometricType.fingerprint)) {
        return Icons.fingerprint;
      }
    }

    if (Platform.isAndroid) {
      if (types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong) ||
          types.contains(BiometricType.weak)) {
        return Icons.fingerprint;
      }
    }

    return Icons.fingerprint;
  }

  Future<bool> authenticate({
    String reason = '请验证身份以解锁保险库',
  }) async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      return isAuthenticated;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          throw BiometricException('设备不支持生物识别');
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          throw BiometricException('未设置生物识别，请在系统设置中添加');
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          throw BiometricException('生物识别暂时不可用，请稍后重试');
        case LocalAuthExceptionCode.temporaryLockout:
          throw BiometricException('生物识别已锁定，请稍后重试');
        case LocalAuthExceptionCode.biometricLockout:
          throw BiometricException('生物识别已被锁定，请使用密码解锁');
        case LocalAuthExceptionCode.noCredentialsSet:
          throw BiometricException('未设置设备锁屏密码');
        case LocalAuthExceptionCode.userCanceled:
          throw BiometricException('用户已取消操作');
        case LocalAuthExceptionCode.deviceError:
          throw BiometricException('设备错误，请重试');
        case LocalAuthExceptionCode.timeout:
          throw BiometricException('操作超时，请重试');
        case LocalAuthExceptionCode.userRequestedFallback:
          throw BiometricException('请使用密码解锁');
        default:
          throw BiometricException('生物识别认证失败，请重试');
      }
    }
  }

  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on LocalAuthException {
      // 忽略取消操作的错误
    }
  }
}

class BiometricException implements Exception {
  final String message;

  BiometricException(this.message);

  @override
  String toString() => message;
}
