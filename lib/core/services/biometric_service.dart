import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// 生物识别服务
///
/// 负责指纹/面容识别的可用性检查、认证执行和类型检测
/// 支持 Android (指纹/面容) 和 iOS (Touch ID / Face ID)
class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService({
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  /// 检查设备是否支持生物识别
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on LocalAuthException {
      return false;
    }
  }

  /// 检查生物识别是否已启用（用户已设置）
  Future<bool> isBiometricEnabled() async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      // 检查是否已注册生物识别
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  /// 获取可用的生物识别类型
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on LocalAuthException {
      return [];
    }
  }

  /// 获取主要生物识别类型的显示名称
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

  /// 获取生物识别图标
  Future<IconData> getBiometricIcon() async {
    final types = await getAvailableBiometrics();

    if (Platform.isIOS) {
      if (types.contains(BiometricType.face)) {
        return Icons.face_retouching_natural_outlined; // Face ID
      }
      if (types.contains(BiometricType.fingerprint)) {
        return Icons.fingerprint; // Touch ID
      }
    }

    if (Platform.isAndroid) {
      if (types.contains(BiometricType.fingerprint) || 
          types.contains(BiometricType.strong) || 
          types.contains(BiometricType.weak)) {
        return Icons.fingerprint; // Android 指纹
      }
    }

    return Icons.fingerprint; // 默认指纹图标
  }

  /// 执行生物识别认证
  ///
  /// [reason] 显示给用户的提示信息
  /// 返回认证是否成功
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
      // 处理各种异常情况
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

  /// 停止当前正在进行的认证（用于取消操作）
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on LocalAuthException {
      // 忽略取消操作的错误
    }
  }
}

/// 生物识别异常
class BiometricException implements Exception {
  final String message;

  BiometricException(this.message);

  @override
  String toString() => message;
}
