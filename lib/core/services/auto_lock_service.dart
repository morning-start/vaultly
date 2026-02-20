import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// 自动锁定服务
///
/// 负责监控用户活动，在闲置一段时间后自动锁定应用
/// 支持的时间间隔：5分钟、15分钟、30分钟
class AutoLockService extends ChangeNotifier {
  static const List<int> lockDurations = [5, 15, 30]; // 分钟
  static const int defaultLockDuration = 5; // 默认5分钟

  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  int _lockDurationMinutes;
  bool _isMonitoring = false;

  // 用户活动监听器
  final List<VoidCallback> _onLockCallbacks = [];

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
    notifyListeners();
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
    notifyListeners();
  }

  /// 停止监控
  void stopMonitoring() {
    _isMonitoring = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    stopMonitoring();
    _onLockCallbacks.clear();
    super.dispose();
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

  /// 锁定触发
  void _onLockTriggered() {
    stopMonitoring();

    // 触发所有注册的回调
    for (final callback in _onLockCallbacks) {
      callback();
    }

    notifyListeners();
  }

  // ==================== 回调注册 ====================

  /// 注册锁定回调
  void addOnLockListener(VoidCallback callback) {
    _onLockCallbacks.add(callback);
  }

  /// 移除锁定回调
  void removeOnLockListener(VoidCallback callback) {
    _onLockCallbacks.remove(callback);
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

/// 自动锁定服务 Provider
final autoLockServiceProvider = ChangeNotifierProvider<AutoLockService>((ref) {
  final service = AutoLockService();

  // 监听锁定事件，触发认证状态锁定
  service.addOnLockListener(() {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    authNotifier.lock();
  });

  // 应用生命周期监听
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// 自动锁定配置 Provider
final autoLockDurationProvider = StateProvider<int>((ref) {
  return AutoLockService.defaultLockDuration;
});

/// 自动锁定启用状态 Provider
final autoLockEnabledProvider = StateProvider<bool>((ref) {
  return true;
});

/// 全局活动监听器 Widget
///
/// 将此 Widget 放在应用顶层，监听所有用户活动
class AutoLockActivityListener extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLockActivityListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AutoLockActivityListener> createState() =>
      _AutoLockActivityListenerState();
}

class _AutoLockActivityListenerState
    extends ConsumerState<AutoLockActivityListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLockService = ref.read(autoLockServiceProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        // 应用回到前台，恢复监控
        autoLockService.resume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // 应用进入后台，暂停监控
        autoLockService.pause();
        break;
      case AppLifecycleState.detached:
        // 应用被销毁
        autoLockService.stopMonitoring();
        break;
    }
  }

  void _startMonitoring() {
    final isEnabled = ref.read(autoLockEnabledProvider);
    if (isEnabled) {
      final autoLockService = ref.read(autoLockServiceProvider);
      autoLockService.startMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      onPointerMove: (_) => _onActivity(),
      child: widget.child,
    );
  }

  void _onActivity() {
    final autoLockService = ref.read(autoLockServiceProvider);
    autoLockService.recordActivity();
  }
}
