import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_models.dart';
import '../data/webdav_client.dart';
import '../data/sync_config_repository.dart';

/// 同步编排器
///
/// 协调 webdav_client 和 config_repository 完成同步逻辑。
/// 保留原 WebDAVService 的所有公开方法。
class SyncOrchestrator {
  final WebDAVClient _client;
  final SyncConfigRepository _configRepository;

  // 状态流控制器
  final _syncStateController = StreamController<SyncState>.broadcast();
  SyncState _currentState = SyncState();

  SyncOrchestrator({
    WebDAVClient? client,
    SyncConfigRepository? configRepository,
  })  : _client = client ?? WebDAVClient(),
        _configRepository = configRepository ?? SyncConfigRepository();

  /// 状态流
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  /// 当前状态
  SyncState get currentState => _currentState;

  /// 是否正在同步
  bool get isSyncing => _currentState.isSyncing;

  /// 清除内存缓存
  void clearCache() {
    _configRepository.clearCache();
    _client.clearConfig();
  }

  /// 检查是否已配置 WebDAV
  Future<bool> isConfigured() async {
    return _configRepository.isConfigured();
  }

  /// 快速检查是否已配置（同步方法）
  bool isConfiguredSync() {
    return _configRepository.isConfiguredSync();
  }

  /// 获取同步配置
  Future<SyncConfig?> getConfig() async {
    return _configRepository.getConfig();
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    await _configRepository.saveConfig(config);
    _client.initClient(config);
  }

  /// 清除配置
  Future<void> clearConfig() async {
    await _configRepository.clearConfig();
    _client.clearConfig();
  }

  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime() async {
    return _configRepository.getLastSyncTime();
  }

  /// 检查远程备份是否存在
  Future<bool> checkRemoteBackup() async {
    final config = await _configRepository.getConfig();
    if (config == null) return false;

    _client.initClient(config);
    return _client.checkRemoteBackup();
  }

  /// 更新同步状态
  void _updateState(SyncState newState) {
    _currentState = newState;
    _syncStateController.add(newState);
  }

  /// 测试连接
  Future<ConnectionResult> testConnection(SyncConfig config) async {
    return _client.testConnection(config);
  }

  /// 统一同步方法
  ///
  /// 流程：
  /// 1. 根据同步模式选择上传/下载/双向同步
  /// 2. 根据配置决定是否加密
  /// 3. 根据配置决定是否压缩
  Future<SyncResult> sync({
    required Map<String, dynamic> localVaultData,
    required Uint8List encryptionKey,
    bool? enableEncryption,
    bool? enableCompression,
    Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null) {
      return SyncResult.failure('同步未配置');
    }

    // 使用配置中的设置，或传入的参数
    final encrypt = enableEncryption ?? config.enableEncryption;
    final compress = enableCompression ?? config.enableCompression;

    _client.initClient(config);

    _updateState(SyncState(
      status: SyncStatus.syncing,
      message: '正在同步...',
      startTime: DateTime.now(),
    ));

    try {
      SyncResult result;

      switch (config.syncMode) {
        case SyncMode.uploadOnly:
          result = await syncUpload(
            vaultData: localVaultData,
            encryptionKey: encryptionKey,
            enableEncryption: encrypt,
            enableCompression: compress,
            onProgress: onProgress,
          );
          break;
        case SyncMode.downloadOnly:
          result = await syncDownload(
            encryptionKey: encryptionKey,
            enableEncryption: encrypt,
            enableCompression: compress,
            onProgress: onProgress,
          );
          break;
        case SyncMode.auto:
        case SyncMode.manual:
          result = await _twoWaySync(
            localVaultData: localVaultData,
            encryptionKey: encryptionKey,
            enableEncryption: encrypt,
            enableCompression: compress,
            onProgress: onProgress,
          );
          break;
      }

      // 保存同步历史
      await _saveSyncHistory(result);

      // 更新状态
      _updateState(SyncState(
        status: result.success ? SyncStatus.success : SyncStatus.failed,
        message: result.success ? '同步成功' : result.errorMessage,
        endTime: DateTime.now(),
        added: result.added,
        updated: result.updated,
        deleted: result.deleted,
        conflicts: result.conflicts,
      ));

      return result;
    } catch (e) {
      final errorResult = SyncResult.failure('同步失败: $e');
      _updateState(SyncState(
        status: SyncStatus.failed,
        message: '同步失败: $e',
        endTime: DateTime.now(),
      ));
      return errorResult;
    }
  }

  /// 双向同步
  Future<SyncResult> _twoWaySync({
    required Map<String, dynamic> localVaultData,
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    // TODO: 实现完整的双向同步逻辑
    // 暂时先上传
    return await syncUpload(
      vaultData: localVaultData,
      encryptionKey: encryptionKey,
      enableEncryption: enableEncryption,
      enableCompression: enableCompression,
      onProgress: onProgress,
    );
  }

  /// 上传同步
  Future<SyncResult> syncUpload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final config = await getConfig();
      if (config == null) {
        return SyncResult.failure('WebDAV 未配置');
      }

      _client.initClient(config);

      final success = await _client.upload(
        vaultData: vaultData,
        encryptionKey: encryptionKey,
        enableEncryption: enableEncryption,
        enableCompression: enableCompression,
        onProgress: onProgress,
      );

      // 更新最后同步时间
      await _configRepository.updateLastSyncTime(DateTime.now());

      if (success) {
        return SyncResult.success(updated: 1);
      } else {
        return SyncResult.failure('上传失败');
      }
    } catch (e) {
      return SyncResult.failure('上传失败: $e');
    }
  }

  /// 下载同步
  Future<SyncResult> syncDownload({
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final config = await getConfig();
      if (config == null) {
        return SyncResult.failure('WebDAV 未配置');
      }

      _client.initClient(config);

      final data = await _client.download(
        encryptionKey: encryptionKey,
        enableEncryption: enableEncryption,
        enableCompression: enableCompression,
        onProgress: onProgress,
      );

      // 更新最后同步时间
      await _configRepository.updateLastSyncTime(DateTime.now());

      if (data != null) {
        return SyncResult.success(updated: 1);
      } else {
        return SyncResult.failure('下载失败：无数据');
      }
    } catch (e) {
      return SyncResult.failure('下载失败: $e');
    }
  }

  /// 上传保险库数据（支持加密/不加密模式）
  Future<bool> upload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null) {
      throw WebDAVException('WebDAV 未配置');
    }

    _client.initClient(config);

    final result = await _client.upload(
      vaultData: vaultData,
      encryptionKey: encryptionKey,
      enableEncryption: enableEncryption,
      enableCompression: enableCompression,
      onProgress: onProgress,
    );

    // 更新最后同步时间
    await _configRepository.updateLastSyncTime(DateTime.now());

    return result;
  }

  /// 下载保险库数据（支持解密/不解密模式）
  Future<Map<String, dynamic>?> download({
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null) {
      throw WebDAVException('WebDAV 未配置');
    }

    _client.initClient(config);

    final result = await _client.download(
      encryptionKey: encryptionKey,
      enableEncryption: enableEncryption,
      enableCompression: enableCompression,
      onProgress: onProgress,
    );

    // 更新最后同步时间
    await _configRepository.updateLastSyncTime(DateTime.now());

    return result;
  }

  /// 解决冲突
  Future<void> resolveConflict(String entryId, ConflictResolution resolution) async {
    // TODO: 实现冲突解决逻辑
    debugPrint('解决冲突: $entryId -> $resolution');
  }

  /// 批量解决冲突
  Future<void> resolveAllConflicts(Map<String, ConflictResolution> resolutions) async {
    for (final entry in resolutions.entries) {
      await resolveConflict(entry.key, entry.value);
    }
  }

  /// 获取同步历史
  Future<List<SyncHistory>> getSyncHistory({int limit = 50}) async {
    return _configRepository.getSyncHistory(limit: limit);
  }

  /// 清除同步历史
  Future<void> clearSyncHistory() async {
    await _configRepository.clearSyncHistory();
  }

  /// 保存同步历史
  Future<void> _saveSyncHistory(SyncResult result) async {
    await _configRepository.saveSyncHistory(result);
  }

  /// 释放资源
  void dispose() {
    _syncStateController.close();
  }
}
