import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_models.dart';
import '../data/webdav_client.dart';
import '../data/sync_config_repository.dart';
import '../../auth/data/crypto_service.dart';

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
  }) : _client = client ?? WebDAVClient(),
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
  /// 当前实现说明（ADR-004）：无论选择何种模式，实际语义均为
  /// 「上传备份」——`_twoWaySync` 尚未实现字段级合并，
  /// auto/manual 模式与 uploadOnly 行为一致。真正的双向同步需要
  /// 合并策略设计（last-write-wins 或字段级 CRDT），另立需求实现。
  ///
  /// 流程：
  /// 1. 根据同步模式路由（当前全部为上传）
  /// 2. 传输固定启用 AES-256-GCM 加密与 GZIP 压缩，
  ///    并把 KDF 参数写进备份文件头，保证换设备也能用主密码恢复
  Future<SyncResult> sync({
    required Map<String, dynamic> localVaultData,
    required Uint8List encryptionKey,
    required KdfParams kdfParams,
    required BackupKeyResolver keyResolver,
    Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null) {
      return SyncResult.failure('同步未配置');
    }

    _client.initClient(config);

    _updateState(
      SyncState(
        status: SyncStatus.syncing,
        message: '正在同步...',
        startTime: DateTime.now(),
      ),
    );

    try {
      SyncResult result;

      switch (config.syncMode) {
        case SyncMode.uploadOnly:
        case SyncMode.auto:
        case SyncMode.manual:
          // TODO(bidirectional): auto/manual 待实现字段级双向合并，
          // 当前按上传备份处理，见方法注释（ADR-004）。
          result = await syncUpload(
            vaultData: localVaultData,
            encryptionKey: encryptionKey,
            kdfParams: kdfParams,
            onProgress: onProgress,
          );
          break;
        case SyncMode.downloadOnly:
          result = await syncDownload(
            keyResolver: keyResolver,
            onProgress: onProgress,
          );
          break;
      }

      // 保存同步历史
      await _saveSyncHistory(result);

      // 更新状态
      _updateState(
        SyncState(
          status: result.success ? SyncStatus.success : SyncStatus.failed,
          message: result.success ? '同步成功' : result.errorMessage,
          endTime: DateTime.now(),
          added: result.added,
          updated: result.updated,
          deleted: result.deleted,
          conflicts: result.conflicts,
        ),
      );

      return result;
    } catch (e) {
      final errorResult = SyncResult.failure('同步失败: $e');
      _updateState(
        SyncState(
          status: SyncStatus.failed,
          message: '同步失败: $e',
          endTime: DateTime.now(),
        ),
      );
      return errorResult;
    }
  }

  /// 上传同步（结果语义包装，实际传输见 [upload]）。
  ///
  /// ADR-004：当前所有同步模式的"双向"实现均为上传备份。
  Future<SyncResult> syncUpload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    required KdfParams kdfParams,
    Function(double progress)? onProgress,
  }) async {
    try {
      final success = await upload(
        vaultData: vaultData,
        encryptionKey: encryptionKey,
        kdfParams: kdfParams,
        onProgress: onProgress,
      );

      if (success) {
        return SyncResult.success(updated: 1);
      } else {
        return SyncResult.failure('上传失败');
      }
    } catch (e) {
      // WebDAVException 已带上下文，避免出现「上传失败: 上传失败: …」的重复前缀
      return SyncResult.failure(
        e is WebDAVException ? e.message : '上传失败: $e',
      );
    }
  }

  /// 下载同步（结果语义包装，实际传输见 [download]）
  Future<SyncResult> syncDownload({
    required BackupKeyResolver keyResolver,
    Function(double progress)? onProgress,
  }) async {
    try {
      final result = await download(
        keyResolver: keyResolver,
        onProgress: onProgress,
      );

      if (result.data.isNotEmpty) {
        return SyncResult.success(updated: 1);
      } else {
        return SyncResult.failure('下载失败：无数据');
      }
    } catch (e) {
      // WebDAVException 已带上下文，避免出现「下载失败: 下载失败: …」的重复前缀
      return SyncResult.failure(
        e is WebDAVException ? e.message : '下载失败: $e',
      );
    }
  }

  /// 上传保险库数据（固定加密 + 压缩）
  Future<bool> upload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    required KdfParams kdfParams,
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
      kdfParams: kdfParams,
      onProgress: onProgress,
    );

    // 更新最后同步时间
    await _configRepository.updateLastSyncTime(DateTime.now());

    return result;
  }

  /// 下载保险库数据（固定解密 + 解压）
  Future<DownloadedBackup> download({
    required BackupKeyResolver keyResolver,
    Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null) {
      throw WebDAVException('WebDAV 未配置');
    }

    _client.initClient(config);

    final result = await _client.download(
      keyResolver: keyResolver,
      onProgress: onProgress,
    );

    // 更新最后同步时间
    await _configRepository.updateLastSyncTime(DateTime.now());

    return result;
  }

  /// 列出远程备份格式（加密 / 明文），供下载前选择
  Future<RemoteBackupFormats> listRemoteBackups() async {
    final config = await _configRepository.getConfig();
    if (config == null) return const RemoteBackupFormats();
    _client.initClient(config);
    return _client.listRemoteBackups();
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
