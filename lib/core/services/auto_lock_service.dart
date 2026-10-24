import 'dart:async';
import 'package:flutter/material.dart';

/// 自动锁定服务（纯逻辑，无 UI / 状态库依赖）
///
/// 负责监控用户闲置时间，到期触发 [onLockRequested] 回调。
/// 支持的时间间隔：5分钟、15分钟、30分钟。
class AutoLockService {
  static const List<int> lockDurations = [5, 15, 30]; // 分钟
  static const int defaultLockDuration = 5; // 默认5分钟

  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  int _lockDurationMinutes;
  bool _isMonitoring = false;

  AutoLockService({int lockDurationMinutes = defaultLockDuration})
      : _lockDurationMinutes = lockDurationMinutes;

  // ==================== 配置 ====================

  /// 获取当前锁定时间（分钟）
  int get lockDurationMinutes => _lockDurationMinutes;

  /// 设置锁定时间
  set lockDurationMinutes(int minutes) {
    if (!lockDurations.contains(minutes)) {
      throw ArgumentError('锁定时间必须是 5、15 或 30 分钟');
    }
    _lockDurationMinutes = minutes;
    _resetTimer();
  }

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;

  /// 获取剩余时间（秒）
  int? get remainingSeconds {
    if (_lastActivityTime == null || _inactivityTimer == null) {
      return null;
    }
    final elapsed = DateTime.now().difference(_lastActivityTime!).inSeconds;
    final total = _lockDurationMinutes * 60;
    return total - elapsed;
  }

  // ==================== 生命周期 ====================

  /// 开始监控用户活动
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _lastActivityTime = DateTime.now();
    _startTimer();
  }

  /// 停止监控
  void stopMonitoring() {
    _isMonitoring = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
  }

  // ==================== 活动跟踪 ====================

  /// 记录用户活动
  ///
  /// 应在用户交互时调用（点击、输入等）
  void recordActivity() {
    if (!_isMonitoring) return;

    _lastActivityTime = DateTime.now();
    _resetTimer();
  }

  /// 重置计时器
  void _resetTimer() {
    _inactivityTimer?.cancel();
    _startTimer();
  }

  /// 启动计时器
  void _startTimer() {
    _inactivityTimer = Timer(
      Duration(minutes: _lockDurationMinutes),
      _onLockTriggered,
    );
  }

  /// 锁定触发 - 由外部注入回调
  VoidCallback? onLockRequested;

  /// 锁定触发
  void _onLockTriggered() {
    stopMonitoring();
    onLockRequested?.call();
  }

  // ==================== 快捷方法 ====================

  /// 立即锁定
  void lockNow() {
    _onLockTriggered();
  }

  /// 暂停监控（例如：在设置页面）
  void pause() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// 恢复监控
  void resume() {
    if (_isMonitoring) {
      recordActivity();
    }
  }
}
