import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    } on PlatformException {
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
    } on PlatformException {
      return false;
    }
  }

  /// 获取可用的生物识别类型
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
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
      if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
        return '指纹';
      }
    }

    return '生物识别';
  }

  /// 获取生物识别图标
  Future<IconData> getBiometricIcon() async {
    final types = await getAvailableBiometrics();

    if (Platform.isIOS && types.contains(BiometricType.face)) {
      return Icons.face_retouching_natural_outlined; // Face ID
    }

    return Icons.fingerprint; // Touch ID 或 Android 指纹
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
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      return isAuthenticated;
    } on PlatformException catch (e) {
      // 处理各种异常情况
      switch (e.code) {
        case 'NotAvailable':
          throw BiometricException('设备不支持生物识别');
        case 'NotEnrolled':
          throw BiometricException('未设置生物识别，请在系统设置中添加');
        case 'LockedOut':
          throw BiometricException('生物识别已锁定，请使用密码解锁');
        case 'PermanentlyLockedOut':
          throw BiometricException('生物识别已被永久锁定，请使用密码解锁');
        case 'PasscodeNotSet':
          throw BiometricException('未设置设备锁屏密码');
        default:
          throw BiometricException('生物识别认证失败: ${e.message}');
      }
    }
  }

  /// 停止当前正在进行的认证（用于取消操作）
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException {
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
