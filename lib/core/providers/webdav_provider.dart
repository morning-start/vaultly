import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/webdav_service.dart';

/// WebDAV 服务提供者 - 使用单例模式确保全局只有一个实例
final webDAVServiceProvider = Provider<WebDAVService>((ref) {
  return WebDAVService();
});

/// WebDAV 配置状态
/// 
/// 使用 immutable 状态类，确保状态变更可追踪
class WebDAVConfigState {
  final bool isConfigured;
  final bool isLoading;
  final DateTime? lastSyncTime;
  final bool hasRemoteBackup;
  final String? error;
  final bool isBackupChecking;

  const WebDAVConfigState({
    this.isConfigured = false,
    this.isLoading = false,
    this.lastSyncTime,
    this.hasRemoteBackup = false,
    this.error,
    this.isBackupChecking = false,
  });

  WebDAVConfigState copyWith({
    bool? isConfigured,
    bool? isLoading,
    DateTime? lastSyncTime,
    bool? hasRemoteBackup,
    String? error,
    bool? isBackupChecking,
  }) {
    return WebDAVConfigState(
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      hasRemoteBackup: hasRemoteBackup ?? this.hasRemoteBackup,
      error: error ?? this.error,
      isBackupChecking: isBackupChecking ?? this.isBackupChecking,
    );
  }

  @override
  String toString() {
    return 'WebDAVConfigState(isConfigured: $isConfigured, isLoading: $isLoading, '
        'hasRemoteBackup: $hasRemoteBackup, isBackupChecking: $isBackupChecking)';
  }
}

/// WebDAV 配置状态管理
/// 
/// 优化策略:
/// 1. 使用内存缓存避免重复 SecureStorage 读取
/// 2. 异步加载远程备份状态，不阻塞 UI
/// 3. 提供同步快速检查方法
class WebDAVConfigNotifier extends StateNotifier<WebDAVConfigState> {
  final WebDAVService _webDAVService;
  bool _isInitialized = false;

  WebDAVConfigNotifier(this._webDAVService) 
      : super(const WebDAVConfigState(isLoading: true)) {
    // 延迟初始化，避免在构造函数中阻塞
    _initialize();
  }

  /// 初始化状态
  /// 
  /// 分两步加载:
  /// 1. 先快速从内存/缓存获取配置状态
  /// 2. 异步检查远程备份状态
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    // 第一步: 快速检查本地配置（使用缓存）
    await _loadLocalConfig();
    
    // 第二步: 异步检查远程备份（不阻塞 UI）
    _checkRemoteBackupAsync();
    
    _isInitialized = true;
  }

  /// 加载本地配置（快速）
  Future<void> _loadLocalConfig() async {
    try {
      // 使用服务的缓存机制，避免重复读取 SecureStorage
      final isConfigured = await _webDAVService.isConfigured();
      final lastSync = await _webDAVService.getLastSyncTime();

      state = state.copyWith(
        isConfigured: isConfigured,
        isLoading: false,
        lastSyncTime: lastSync,
        hasRemoteBackup: false, // 先设为 false，等待异步检查
        isBackupChecking: isConfigured, // 如果已配置，标记为正在检查
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 异步检查远程备份状态
  /// 
  /// 这是一个网络操作，可能耗时较长，所以单独异步执行
  Future<void> _checkRemoteBackupAsync() async {
    if (!state.isConfigured) return;

    try {
      final hasBackup = await _webDAVService.checkRemoteBackup();
      
      // 只在状态变化时更新，避免不必要的重建
      if (state.hasRemoteBackup != hasBackup || state.isBackupChecking) {
        state = state.copyWith(
          hasRemoteBackup: hasBackup,
          isBackupChecking: false,
        );
      }
    } catch (e) {
      // 静默失败，不影响用户体验
      state = state.copyWith(isBackupChecking: false);
    }
  }

  /// 刷新配置状态
  /// 
  /// 强制重新从存储读取，清除缓存
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    
    // 清除服务层缓存
    _webDAVService.clearCache();
    
    // 重新初始化
    _isInitialized = false;
    await _initialize();
  }

  /// 快速刷新（仅检查本地配置）
  Future<void> refreshLocal() async {
    await _loadLocalConfig();
  }

  /// 更新同步时间
  void updateSyncTime(DateTime time) {
    state = state.copyWith(lastSyncTime: time);
  }

  /// 更新远程备份状态
  void updateRemoteBackupStatus(bool hasBackup) {
    state = state.copyWith(
      hasRemoteBackup: hasBackup,
      isBackupChecking: false,
    );
  }

  /// 标记正在检查备份
  void setBackupChecking(bool checking) {
    state = state.copyWith(isBackupChecking: checking);
  }
}

/// WebDAV 配置状态提供者
/// 
/// 使用 StateNotifierProvider 管理复杂状态
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
