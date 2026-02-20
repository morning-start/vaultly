import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/webdav_service.dart';

/// WebDAV 服务提供者
final webDAVServiceProvider = Provider<WebDAVService>((ref) {
  return WebDAVService();
});

/// WebDAV 配置状态
class WebDAVConfigState {
  final bool isConfigured;
  final bool isLoading;
  final DateTime? lastSyncTime;
  final bool hasRemoteBackup;
  final String? error;

  const WebDAVConfigState({
    this.isConfigured = false,
    this.isLoading = true,
    this.lastSyncTime,
    this.hasRemoteBackup = false,
    this.error,
  });

  WebDAVConfigState copyWith({
    bool? isConfigured,
    bool? isLoading,
    DateTime? lastSyncTime,
    bool? hasRemoteBackup,
    String? error,
  }) {
    return WebDAVConfigState(
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      hasRemoteBackup: hasRemoteBackup ?? this.hasRemoteBackup,
      error: error ?? this.error,
    );
  }
}

/// WebDAV 配置状态管理
class WebDAVConfigNotifier extends StateNotifier<WebDAVConfigState> {
  final WebDAVService _webDAVService;

  WebDAVConfigNotifier(this._webDAVService) : super(const WebDAVConfigState()) {
    // 初始化时加载配置
    _loadConfig();
  }

  /// 加载配置状态
  Future<void> _loadConfig() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final isConfigured = await _webDAVService.isConfigured();
      final lastSync = await _webDAVService.getLastSyncTime();
      bool hasBackup = false;

      if (isConfigured) {
        hasBackup = await _webDAVService.checkRemoteBackup();
      }

      state = state.copyWith(
        isConfigured: isConfigured,
        isLoading: false,
        lastSyncTime: lastSync,
        hasRemoteBackup: hasBackup,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新配置状态
  Future<void> refresh() async {
    await _loadConfig();
  }

  /// 更新同步时间
  void updateSyncTime(DateTime time) {
    state = state.copyWith(lastSyncTime: time);
  }

  /// 更新远程备份状态
  void updateRemoteBackupStatus(bool hasBackup) {
    state = state.copyWith(hasRemoteBackup: hasBackup);
  }
}

/// WebDAV 配置状态提供者
final webDAVConfigProvider = StateNotifierProvider<WebDAVConfigNotifier, WebDAVConfigState>((ref) {
  final webDAVService = ref.watch(webDAVServiceProvider);
  return WebDAVConfigNotifier(webDAVService);
});

/// 同步操作状态
class SyncOperationState {
  final bool isSyncing;
  final double progress;
  final String? statusMessage;
  final String? error;

  const SyncOperationState({
    this.isSyncing = false,
    this.progress = 0,
    this.statusMessage,
    this.error,
  });

  SyncOperationState copyWith({
    bool? isSyncing,
    double? progress,
    String? statusMessage,
    String? error,
  }) {
    return SyncOperationState(
      isSyncing: isSyncing ?? this.isSyncing,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error ?? this.error,
    );
  }
}

/// 同步操作状态管理
class SyncOperationNotifier extends StateNotifier<SyncOperationState> {
  SyncOperationNotifier() : super(const SyncOperationState());

  void startSync(String message) {
    state = SyncOperationState(
      isSyncing: true,
      progress: 0,
      statusMessage: message,
    );
  }

  void updateProgress(double progress, String message) {
    state = state.copyWith(
      progress: progress,
      statusMessage: message,
    );
  }

  void completeSync(String message) {
    state = SyncOperationState(
      isSyncing: false,
      progress: 1.0,
      statusMessage: message,
    );
  }

  void setError(String error) {
    state = SyncOperationState(
      isSyncing: false,
      progress: 0,
      error: error,
    );
  }

  void reset() {
    state = const SyncOperationState();
  }
}

/// 同步操作状态提供者
final syncOperationProvider = StateNotifierProvider<SyncOperationNotifier, SyncOperationState>((ref) {
  return SyncOperationNotifier();
});
