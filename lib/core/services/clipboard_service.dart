import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 剪贴板服务
///
/// 参考文档: wiki/02-架构设计/安全架构.md 第 3.3 节
/// 提供安全的剪贴板操作，支持自动清除敏感数据
class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  // 存储正在运行的清除计时器
  final Map<String, Timer> _clearTimers = {};

  /// 默认清除时间（秒）
  static const int defaultClearDelaySeconds = 30;

  /// 复制文本到剪贴板
  ///
  /// [label] 用于标识此次复制操作，用于后续清除
  /// [clearAfterSeconds] 自动清除时间，null 表示不清除
  Future<void> copyText(
    String text, {
    String? label,
    int? clearAfterSeconds = defaultClearDelaySeconds,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    // 设置自动清除
    if (clearAfterSeconds != null && clearAfterSeconds > 0) {
      _scheduleClear(label ?? 'default', clearAfterSeconds);
    }
  }

  /// 从剪贴板读取文本
  Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  /// 清除剪贴板
  Future<void> clear() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  /// 安排清除任务
  void _scheduleClear(String label, int seconds) {
    // 取消已有的计时器
    _clearTimers[label]?.cancel();

    // 创建新的计时器
    _clearTimers[label] = Timer(Duration(seconds: seconds), () async {
      await clear();
      _clearTimers.remove(label);
    });
  }

  /// 取消指定标签的清除任务
  void cancelClear(String label) {
    _clearTimers[label]?.cancel();
    _clearTimers.remove(label);
  }

  /// 清除所有敏感的剪贴板内容
  Future<void> clearAllSensitive() async {
    // 取消所有计时器
    for (final timer in _clearTimers.values) {
      timer.cancel();
    }
    _clearTimers.clear();

    // 清除剪贴板
    await clear();
  }

  /// 复制敏感数据（密码等）
  ///
  /// 敏感数据会在 30 秒后自动清除
  Future<void> copySensitive(String text, {String? label}) async {
    await copyText(
      text,
      label: label ?? 'sensitive',
      clearAfterSeconds: defaultClearDelaySeconds,
    );
  }

  /// 复制 TOTP 验证码
  ///
  /// TOTP 验证码会在 30 秒后自动清除
  Future<void> copyTOTP(String code) async {
    await copySensitive(code, label: 'totp');
  }

  /// 复制用户名
  ///
  /// 用户名不是敏感数据，不会自动清除
  Future<void> copyUsername(String username) async {
    await copyText(
      username,
      label: 'username',
      clearAfterSeconds: null, // 不清除
    );
  }

  /// 复制 URL
  ///
  /// URL 不是敏感数据，不会自动清除
  Future<void> copyURL(String url) async {
    await copyText(
      url,
      label: 'url',
      clearAfterSeconds: null, // 不清除
    );
  }

  /// 检查剪贴板是否包含敏感数据
  ///
  /// 注意：这只是一个启发式检查，不保证 100% 准确
  Future<bool> containsSensitiveData() async {
    final text = await getText();
    if (text == null || text.isEmpty) {
      return false;
    }

    // 检查是否是密码（常见模式）
    // 1. 包含大写、小写、数字和特殊字符
    // 2. 长度在 8-64 之间
    final hasUppercase = text.contains(RegExp(r'[A-Z]'));
    final hasLowercase = text.contains(RegExp(r'[a-z]'));
    final hasNumbers = text.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasValidLength = text.length >= 8 && text.length <= 64;

    if (hasUppercase &&
        hasLowercase &&
        hasNumbers &&
        hasSpecialChars &&
        hasValidLength) {
      return true;
    }

    // 检查是否是 TOTP 验证码（6位数字）
    if (RegExp(r'^\d{6}$').hasMatch(text)) {
      return true;
    }

    return false;
  }
}

/// 剪贴板保护 mixin
///
/// 用于在页面中自动管理剪贴板安全
mixin ClipboardProtectionMixin<T extends StatefulWidget> on State<T> {
  final ClipboardService _clipboardService = ClipboardService();

  /// 页面失去焦点时是否清除剪贴板
  bool get clearClipboardOnInactive => true;

  /// 页面不可见时是否清除剪贴板
  bool get clearClipboardOnBackground => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
      onStateChanged: _onAppLifecycleStateChanged,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_AppLifecycleObserver(
      onStateChanged: _onAppLifecycleStateChanged,
    ));
    super.dispose();
  }

  void _onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        if (clearClipboardOnInactive) {
          _clipboardService.clearAllSensitive();
        }
        break;
      case AppLifecycleState.paused:
        if (clearClipboardOnBackground) {
          _clipboardService.clearAllSensitive();
        }
        break;
      default:
        break;
    }
  }
}

/// 应用生命周期观察者
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) onStateChanged;

  _AppLifecycleObserver({required this.onStateChanged});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}
