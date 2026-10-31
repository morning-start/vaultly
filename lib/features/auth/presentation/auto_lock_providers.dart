import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auto_lock_service.dart';
import 'auth_providers.dart';

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

/// 自动锁定服务提供者
final autoLockServiceProvider = Provider<AutoLockService>((ref) {
  final service = AutoLockService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 自动锁定状态提供者
///
/// 锁定触发时联动认证与保险库：authNotifier.lock() 内部会
/// 通过 SessionKeyBridge revoke 密钥 → VaultNotifier 清空内存态。
final autoLockNotifierProvider =
    StateNotifierProvider<AutoLockNotifier, AutoLockState>((ref) {
      final service = ref.watch(autoLockServiceProvider);
      final notifier = AutoLockNotifier(service);

      service.onLockRequested = () {
        notifier.stopMonitoring();
        ref.read(authNotifierProvider.notifier).lock();
      };

      return notifier;
    });

/// 全局活动监听器 Widget
///
/// 挂载在应用顶层（main.dart），监听所有用户活动与应用生命周期，
/// 驱动自动锁定。此前该组件从未被挂载导致自动锁功能整体失效。
class AutoLockActivityListener extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLockActivityListener({super.key, required this.child});

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
    // 延迟到帧结束后启动，避免在 widget 生命周期内修改 provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startMonitoring();
    });
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
    ref.read(autoLockNotifierProvider.notifier).recordActivity();
  }
}
