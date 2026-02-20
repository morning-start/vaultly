import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// 自动锁定服务
///
/// 参考文档: wiki/02-架构设计/安全架构.md 第 3.1 节
/// 管理应用自动锁定逻辑
class AutoLockService extends ChangeNotifier {
  final Ref _ref;
  Timer? _inactivityTimer;
  DateTime? _lastActivity;

  // 锁定超时设置（分钟）
  static const int _defaultLockTimeout = 5;
  int _lockTimeoutMinutes = _defaultLockTimeout;

  // 是否在后台时立即锁定
  bool _lockOnBackground = false;

  // 是否启用自动锁定
  bool _enabled = true;

  AutoLockService(this._ref) {
    _startTimer();
  }

  // ==================== 配置 ====================

  /// 获取锁定超时时间（分钟）
  int get lockTimeoutMinutes => _lockTimeoutMinutes;

  /// 设置锁定超时时间
  set lockTimeoutMinutes(int minutes) {
    _lockTimeoutMinutes = minutes;
    _restartTimer();
    notifyListeners();
  }

  /// 是否在后台时立即锁定
  bool get lockOnBackground => _lockOnBackground;

  /// 设置是否在后台时立即锁定
  set lockOnBackground(bool value) {
    _lockOnBackground = value;
    notifyListeners();
  }

  /// 是否启用自动锁定
  bool get enabled => _enabled;

  /// 设置是否启用自动锁定
  set enabled(bool value) {
    _enabled = value;
    if (value) {
      _startTimer();
    } else {
      _stopTimer();
    }
    notifyListeners();
  }

  // ==================== 活动追踪 ====================

  /// 记录用户活动
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  /// 获取上次活动时间
  DateTime? get lastActivity => _lastActivity;

  /// 获取不活动时间（秒）
  int get inactiveSeconds {
    if (_lastActivity == null) return 0;
    return DateTime.now().difference(_lastActivity!).inSeconds;
  }

  /// 获取不活动时间（分钟）
  int get inactiveMinutes => inactiveSeconds ~/ 60;

  /// 检查是否应该锁定
  bool get shouldLock {
    if (!_enabled) return false;
    if (_lastActivity == null) return false;
    return inactiveMinutes >= _lockTimeoutMinutes;
  }

  // ==================== 定时器管理 ====================

  void _startTimer() {
    _stopTimer();
    if (!_enabled) return;

    _inactivityTimer = Timer.periodic(
      const Duration(seconds: 10), // 每 10 秒检查一次
      (_) => _checkAndLock(),
    );
  }

  void _stopTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _restartTimer() {
    _startTimer();
  }

  void _checkAndLock() {
    if (shouldLock) {
      _performLock();
    }
  }

  void _performLock() {
    final authNotifier = _ref.read(authNotifierProvider.notifier);
    authNotifier.lock();
  }

  // ==================== 生命周期 ====================

  /// 应用进入前台
  void onAppResumed() {
    if (_enabled && shouldLock) {
      _performLock();
    }
    recordActivity();
  }

  /// 应用进入后台
  void onAppPaused() {
    if (_lockOnBackground) {
      _performLock();
    }
    recordActivity();
  }

  /// 应用变为非活动状态
  void onAppInactive() {
    // 可以在这里添加额外的逻辑
  }

  /// 立即锁定
  void lockNow() {
    _performLock();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// 自动锁定服务 Provider
final autoLockServiceProvider = ChangeNotifierProvider<AutoLockService>((ref) {
  return AutoLockService(ref);
});

/// 自动锁定包装器
///
/// 包装应用以监听用户活动
class AutoLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLockWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends ConsumerState<AutoLockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        autoLockService.onAppResumed();
        break;
      case AppLifecycleState.paused:
        autoLockService.onAppPaused();
        break;
      case AppLifecycleState.inactive:
        autoLockService.onAppInactive();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoLockService = ref.watch(autoLockServiceProvider);

    return Listener(
      onPointerDown: (_) => autoLockService.recordActivity(),
      onPointerMove: (_) => autoLockService.recordActivity(),
      onPointerUp: (_) => autoLockService.recordActivity(),
      child: GestureDetector(
        onTap: () => autoLockService.recordActivity(),
        onDoubleTap: () => autoLockService.recordActivity(),
        onLongPress: () => autoLockService.recordActivity(),
        onPanUpdate: (_) => autoLockService.recordActivity(),
        onScaleUpdate: (_) => autoLockService.recordActivity(),
        child: widget.child,
      ),
    );
  }
}

/// 自动锁定设置对话框
class AutoLockSettingsDialog extends ConsumerWidget {
  const AutoLockSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLockService = ref.watch(autoLockServiceProvider);

    return AlertDialog(
      title: const Text('自动锁定设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('启用自动锁定'),
            subtitle: const Text('在一段时间不活动后自动锁定应用'),
            value: autoLockService.enabled,
            onChanged: (value) => autoLockService.enabled = value,
          ),
          if (autoLockService.enabled) ...[
            const Divider(),
            ListTile(
              title: const Text('锁定超时时间'),
              subtitle: Text('${autoLockService.lockTimeoutMinutes} 分钟'),
            ),
            Slider(
              value: autoLockService.lockTimeoutMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: '${autoLockService.lockTimeoutMinutes} 分钟',
              onChanged: (value) {
                autoLockService.lockTimeoutMinutes = value.round();
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('进入后台时立即锁定'),
              subtitle: const Text('应用切换到后台时立即锁定'),
              value: autoLockService.lockOnBackground,
              onChanged: (value) => autoLockService.lockOnBackground = value,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
