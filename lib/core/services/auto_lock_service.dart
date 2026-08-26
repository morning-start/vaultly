import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_providers.dart';

/// 自动锁定服务
///
/// 负责监控用户活动，在闲置一段时间后自动锁定应用
/// 支持的时间间隔：5分钟、15分钟、30分钟
///
/// 重构为纯逻辑类，状态管理由 Riverpod Notifier 负责。
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

/// 自动锁定状态
class AutoLockState {
  final bool isEnabled;
  final int durationMinutes;
  final bool isMonitoring;
  final int? remainingSeconds;

  const AutoLockState({
    this.isEnabled = true,
    this.durationMinutes = AutoLockService.defaultLockDuration,
    this.isMonitoring = false,
    this.remainingSeconds,
  });

  AutoLockState copyWith({
    bool? isEnabled,
    int? durationMinutes,
    bool? isMonitoring,
    int? remainingSeconds,
  }) {
    return AutoLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// 自动锁定状态管理 Notifier
class AutoLockNotifier extends StateNotifier<AutoLockState> {
  final AutoLockService _service;
  Timer? _refreshTimer;

  AutoLockNotifier(this._service) : super(const AutoLockState());

  /// 初始化配置
  void initialize({required bool enabled, required int durationMinutes}) {
    _service.lockDurationMinutes = durationMinutes;
    state = state.copyWith(
      isEnabled: enabled,
      durationMinutes: durationMinutes,
    );
    if (enabled) {
      startMonitoring();
    }
  }

  /// 开始监控
  void startMonitoring() {
    _service.startMonitoring();
    state = state.copyWith(isMonitoring: true);
    _startRefreshTimer();
  }

  /// 停止监控
  void stopMonitoring() {
    _service.stopMonitoring();
    state = state.copyWith(isMonitoring: false);
    _stopRefreshTimer();
  }

  /// 切换启用状态
  void toggleEnabled() {
    final newEnabled = !state.isEnabled;
    state = state.copyWith(isEnabled: newEnabled);
    if (newEnabled) {
      startMonitoring();
    } else {
      stopMonitoring();
    }
  }

  /// 更新锁定时长
  void updateDuration(int minutes) {
    _service.lockDurationMinutes = minutes;
    state = state.copyWith(durationMinutes: minutes);
  }

  /// 记录用户活动
  void recordActivity() {
    _service.recordActivity();
  }

  /// 暂停监控
  void pause() {
    _service.pause();
  }

  /// 恢复监控
  void resume() {
    _service.resume();
    if (state.isMonitoring) {
      _startRefreshTimer();
    }
  }

  /// 立即锁定
  void lockNow() {
    _service.lockNow();
    state = state.copyWith(isMonitoring: false);
  }

  void _startRefreshTimer() {
    _stopRefreshTimer();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _service.remainingSeconds;
      state = state.copyWith(remainingSeconds: remaining);
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    _service.dispose();
    super.dispose();
  }
}

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
    final autoLockNotifier = ref.read(autoLockNotifierProvider.notifier);

    switch (state) {
      case AppLifecycleState.resumed:
        autoLockNotifier.resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        autoLockNotifier.pause();
      case AppLifecycleState.detached:
        autoLockNotifier.stopMonitoring();
    }
  }

  void _startMonitoring() {
    final isEnabled = ref.read(autoLockNotifierProvider).isEnabled;
    if (isEnabled) {
      ref.read(autoLockNotifierProvider.notifier).startMonitoring();
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
    final autoLockNotifier = ref.read(autoLockNotifierProvider.notifier);
    autoLockNotifier.recordActivity();
  }
}

/// Providers

final autoLockServiceProvider = Provider<AutoLockService>((ref) {
  final service = AutoLockService();
  ref.onDispose(() => service.dispose());
  return service;
});

final autoLockNotifierProvider =
    StateNotifierProvider<AutoLockNotifier, AutoLockState>((ref) {
  final service = ref.watch(autoLockServiceProvider);
  final notifier = AutoLockNotifier(service);

  // 监听锁定事件，触发认证状态锁定
  service.onLockRequested = () {
    // 直接调用 stopMonitoring，它内部会更新状态
    notifier.stopMonitoring();
    final authNotifier = ref.read(authNotifierProvider.notifier);
    authNotifier.lock();
  };

  return notifier;
});

/// 兼容旧代码的 Provider（逐步迁移）
final autoLockDurationProvider = StateProvider<int>((ref) {
  return AutoLockService.defaultLockDuration;
});

final autoLockEnabledProvider = StateProvider<bool>((ref) {
  return true;
});
