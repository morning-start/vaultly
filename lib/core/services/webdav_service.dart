import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../crypto/services/crypto_service.dart';
import '../models/sync_models.dart';

/// WebDAV 同步服务
///
/// 参考文档: wiki/03-模块设计/同步模块.md
/// 负责与 WebDAV 服务器通信，实现数据同步
///
/// 安全设计:
/// - 数据在传输前使用 AES-256-GCM 加密
/// - 加密密钥由用户主密码通过 Argon2id 派生
/// - 支持 GZIP 压缩减少传输体积
/// - 服务器仅存储密文，无法获取用户数据
///
/// 性能优化:
/// - 使用内存缓存减少 SecureStorage 读取
/// - 异步初始化避免阻塞 UI
/// - 批量操作减少 IO 次数
class WebDAVService {
  static const _keyWebDavUrl = 'webdav_url';
  static const _keyWebDavUsername = 'webdav_username';
  static const _keyWebDavPassword = 'webdav_password';
  static const _keyLastSyncTime = 'webdav_last_sync';
  static const _keySyncHistory = 'webdav_sync_history';
  static const _vaultFolderName = 'vaultly';
  static const _vaultFileName = 'vaultly_backup.enc';

  final FlutterSecureStorage _secureStorage;
  Client? _client;

  // 状态流控制器
  final _syncStateController = StreamController<SyncState>.broadcast();
  SyncState _currentState = SyncState();

  // 内存缓存
  SyncConfig? _cachedConfig;
  bool? _cachedIsConfigured;
  DateTime? _configCacheTime;
  static const _cacheValidityDuration = Duration(seconds: 30);

  WebDAVService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 状态流
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  /// 当前状态
  SyncState get currentState => _currentState;

  /// 是否正在同步
  bool get isSyncing => _currentState.isSyncing;

  /// 检查缓存是否有效
  bool get _isCacheValid {
    if (_configCacheTime == null || _cachedConfig == null) return false;
    return DateTime.now().difference(_configCacheTime!) < _cacheValidityDuration;
  }

  /// 清除内存缓存
  void clearCache() {
    _cachedConfig = null;
    _cachedIsConfigured = null;
    _configCacheTime = null;
  }

  /// 更新同步状态
  void _updateState(SyncState newState) {
    _currentState = newState;
    _syncStateController.add(newState);
  }

  /// 检查是否已配置 WebDAV
  Future<bool> isConfigured() async {
    if (_cachedIsConfigured != null && _isCacheValid) {
      return _cachedIsConfigured!;
    }

    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);

    final isConfigured = url != null &&
        url.isNotEmpty &&
        username != null &&
        password != null;

    _cachedIsConfigured = isConfigured;
    _configCacheTime = DateTime.now();

    return isConfigured;
  }

  /// 快速检查是否已配置（同步方法）
  bool isConfiguredSync() {
    return _cachedIsConfigured ?? false;
  }

  /// 获取同步配置
  Future<SyncConfig?> getConfig() async {
    if (_cachedConfig != null && _isCacheValid) {
      return _cachedConfig;
    }

    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);

    if (url == null || username == null || password == null) {
      return null;
    }

    final config = SyncConfig(
      id: 'webdav_default',
      serverUrl: url,
      username: username,
      password: password,
    );

    _cachedConfig = config;
    _configCacheTime = DateTime.now();

    return config;
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    await _secureStorage.write(key: _keyWebDavUrl, value: config.serverUrl);
    await _secureStorage.write(key: _keyWebDavUsername, value: config.username);
    await _secureStorage.write(key: _keyWebDavPassword, value: config.password ?? '');

    _cachedConfig = config;
    _cachedIsConfigured = true;
    _configCacheTime = DateTime.now();

    _initClient(config);
  }

  /// 清除配置
  Future<void> clearConfig() async {
    await _secureStorage.delete(key: _keyWebDavUrl);
    await _secureStorage.delete(key: _keyWebDavUsername);
    await _secureStorage.delete(key: _keyWebDavPassword);
    await _secureStorage.delete(key: _keyLastSyncTime);
    _client = null;
    clearCache();
  }

  /// 初始化 WebDAV 客户端
  void _initClient(SyncConfig config) {
    _client = newClient(
      config.serverUrl,
      user: config.username,
      password: config.password ?? '',
    );
  }

  /// 确保 vaultly 文件夹存在
  Future<void> _ensureVaultFolder() async {
    if (_client == null) {
      throw WebDAVException('WebDAV 客户端未初始化');
    }

    try {
      final files = await _client!.readDir('/');
      final folderExists = files.any((f) => f.name == _vaultFolderName && f.isDir == true);

      if (!folderExists) {
        await _client!.mkdir('/$_vaultFolderName');
        debugPrint('WebDAV: 已创建 vaultly 文件夹');
      }
    } catch (e) {
      debugPrint('WebDAV: 创建 vaultly 文件夹失败: $e');
      throw WebDAVException('无法创建 vaultly 文件夹: $e');
    }
  }

  /// 测试连接
  Future<ConnectionResult> testConnection(SyncConfig config) async {
    try {
      final client = newClient(
        config.serverUrl,
        user: config.username,
        password: config.password ?? '',
      );

      await client.ping();
      return ConnectionResult.success();
    } catch (e) {
      debugPrint('WebDAV connection test failed: $e');
      return ConnectionResult.failure('连接失败: $e');
    }
  }

  /// 统一同步方法
  ///
  /// 流程：
  /// 1. 根据同步模式选择上传/下载/双向同步
  /// 2. 数据加密后传输
  /// 3. 可选 GZIP 压缩
  Future<SyncResult> sync({
    required Map<String, dynamic> localVaultData,
    required Uint8List encryptionKey,
    bool compress = true,
    Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null) {
      return SyncResult.failure('同步未配置');
    }

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
            compress: compress,
            onProgress: onProgress,
          );
          break;
        case SyncMode.downloadOnly:
          result = await syncDownload(
            encryptionKey: encryptionKey,
            compress: compress,
            onProgress: onProgress,
          );
          break;
        case SyncMode.auto:
        case SyncMode.manual:
          result = await _twoWaySync(
            localVaultData: localVaultData,
            encryptionKey: encryptionKey,
            compress: compress,
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
    bool compress = true,
    Function(double progress)? onProgress,
  }) async {
    // TODO: 实现完整的双向同步逻辑
    // 暂时先上传
    return await syncUpload(
      vaultData: localVaultData,
      encryptionKey: encryptionKey,
      compress: compress,
      onProgress: onProgress,
    );
  }

  /// 上传同步
  Future<SyncResult> syncUpload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    bool compress = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final success = await upload(
        vaultData: vaultData,
        encryptionKey: encryptionKey,
        compress: compress,
        onProgress: onProgress,
      );

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
    bool compress = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final data = await download(
        encryptionKey: encryptionKey,
        compress: compress,
        onProgress: onProgress,
      );

      if (data != null) {
        return SyncResult.success(updated: 1);
      } else {
        return SyncResult.failure('下载失败：无数据');
      }
    } catch (e) {
      return SyncResult.failure('下载失败: $e');
    }
  }

  /// 上传保险库数据（加密 + 压缩）
  ///
  /// 加密流程：
  /// ```
  /// 用户主密码
  ///      ↓
  /// Argon2id 密钥派生 (256-bit)
  ///      ↓
  /// AES-256-GCM 加密
  ///      ↓
  /// GZIP 压缩（可选）
  ///      ↓
  /// WebDAV 服务器（仅存储密文）
  /// ```
  ///
  /// 参数:
  /// - [vaultData]: 要上传的保险库数据
  /// - [encryptionKey]: 加密密钥（由主密码派生）
  /// - [compress]: 是否启用 GZIP 压缩（默认 true）
  /// - [onProgress]: 上传进度回调
  Future<bool> upload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    bool compress = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final config = await getConfig();
      if (config == null) {
        throw WebDAVException('WebDAV 未配置');
      }

      if (_client == null) {
        _initClient(config);
      }

      await _ensureVaultFolder();

      // Step 1: 序列化为 JSON
      final jsonData = jsonEncode(vaultData);
      final jsonBytes = utf8.encode(jsonData);
      debugPrint('WebDAV: 原始数据大小: ${jsonBytes.length} bytes');
      
      // Step 2: AES-256-GCM 加密（使用主密码派生的密钥）
      final encryptedData = CryptoService.encrypt(jsonData, encryptionKey);
      final encryptedJson = jsonEncode(encryptedData.toJson());
      var dataBytes = Uint8List.fromList(utf8.encode(encryptedJson));
      debugPrint('WebDAV: 加密后大小: ${dataBytes.length} bytes');
      
      // Step 3: (可选) GZIP 压缩
      if (compress) {
        dataBytes = _gzipCompress(dataBytes);
        debugPrint('WebDAV: 压缩后大小: ${dataBytes.length} bytes');
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileName');
      await tempFile.writeAsBytes(dataBytes);

      await _client!.writeFromFile(
        tempFile.path,
        '/$_vaultFolderName/$_vaultFileName',
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      await _secureStorage.write(
        key: _keyLastSyncTime,
        value: DateTime.now().toIso8601String(),
      );

      await tempFile.delete();
      
      debugPrint('WebDAV: 上传成功');

      return true;
    } catch (e) {
      debugPrint('WebDAV upload failed: $e');
      throw WebDAVException('上传失败: $e');
    }
  }

  /// 下载保险库数据（解密 + 解压）
  ///
  /// 解密流程：
  /// ```
  /// WebDAV 服务器
  ///      ↓
  /// GZIP 解压（可选）
  ///      ↓
  /// AES-256-GCM 解密
  ///      ↓
  /// Argon2id 密钥验证
  ///      ↓
  /// 保险库数据
  /// ```
  ///
  /// 参数:
  /// - [encryptionKey]: 解密密钥（由主密码派生）
  /// - [compress]: 是否启用 GZIP 解压（默认 true）
  /// - [onProgress]: 下载进度回调
  Future<Map<String, dynamic>?> download({
    required Uint8List encryptionKey,
    bool compress = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final config = await getConfig();
      if (config == null) {
        throw WebDAVException('WebDAV 未配置');
      }

      if (_client == null) {
        _initClient(config);
      }

      await _ensureVaultFolder();

      final files = await _client!.readDir('/$_vaultFolderName');
      final hasBackup = files.any((f) => f.name == _vaultFileName);
      if (!hasBackup) {
        throw WebDAVException('备份文件不存在');
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileName');

      await _client!.read2File(
        '/$_vaultFolderName/$_vaultFileName',
        tempFile.path,
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      // Step 1: 读取数据
      var dataBytes = await tempFile.readAsBytes();
      debugPrint('WebDAV: 下载数据大小: ${dataBytes.length} bytes');
      
      // Step 2: (可选) GZIP 解压
      if (compress) {
        dataBytes = _gzipDecompress(dataBytes);
        debugPrint('WebDAV: 解压后大小: ${dataBytes.length} bytes');
      }
      
      // Step 3: AES-256-GCM 解密
      final encryptedJson = utf8.decode(dataBytes);
      final encryptedData = EncryptedData.fromJson(
        jsonDecode(encryptedJson) as Map<String, dynamic>
      );
      final decryptedJson = CryptoService.decrypt(encryptedData, encryptionKey);
      debugPrint('WebDAV: 解密成功');
      
      // Step 4: 反序列化为 JSON
      final data = jsonDecode(decryptedJson) as Map<String, dynamic>;

      await tempFile.delete();

      await _secureStorage.write(
        key: _keyLastSyncTime,
        value: DateTime.now().toIso8601String(),
      );

      return data;
    } catch (e) {
      debugPrint('WebDAV download failed: $e');
      throw WebDAVException('下载失败: $e');
    }
  }

  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime() async {
    final timeStr = await _secureStorage.read(key: _keyLastSyncTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// 检查远程备份是否存在
  Future<bool> checkRemoteBackup() async {
    try {
      final config = await getConfig();
      if (config == null) return false;

      if (_client == null) {
        _initClient(config);
      }

      final rootFiles = await _client!.readDir('/');
      final folderExists = rootFiles.any((f) => f.name == _vaultFolderName && f.isDir == true);
      if (!folderExists) {
        return false;
      }

      final files = await _client!.readDir('/$_vaultFolderName');
      return files.any((f) => f.name == _vaultFileName);
    } catch (e) {
      return false;
    }
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
    try {
      final historyJson = await _secureStorage.read(key: _keySyncHistory);
      if (historyJson == null) return [];

      final List<dynamic> historyList = jsonDecode(historyJson);
      final histories = historyList
          .map((e) => SyncHistory.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return histories.take(limit).toList();
    } catch (e) {
      debugPrint('获取同步历史失败: $e');
      return [];
    }
  }

  /// 清除同步历史
  Future<void> clearSyncHistory() async {
    await _secureStorage.delete(key: _keySyncHistory);
  }

  /// 保存同步历史
  Future<void> _saveSyncHistory(SyncResult result) async {
    try {
      final history = await getSyncHistory(limit: 100);
      final newEntry = SyncHistory(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        success: result.success,
        added: result.added,
        updated: result.updated,
        deleted: result.deleted,
        conflicts: result.conflicts.length,
        errorMessage: result.errorMessage,
      );

      history.insert(0, newEntry);

      // 只保留最近100条
      final limitedHistory = history.take(100).toList();
      await _secureStorage.write(
        key: _keySyncHistory,
        value: jsonEncode(limitedHistory.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存同步历史失败: $e');
    }
  }

  /// GZIP 压缩
  ///
  /// 使用 Dart 内置的 GZIP 压缩算法
  Uint8List _gzipCompress(Uint8List data) {
    final compressed = io.gzip.encode(data);
    return Uint8List.fromList(compressed);
  }

  /// GZIP 解压
  ///
  /// 使用 Dart 内置的 GZIP 解压算法
  Uint8List _gzipDecompress(Uint8List data) {
    final decompressed = io.gzip.decode(data);
    return Uint8List.fromList(decompressed);
  }

  /// 释放资源
  void dispose() {
    _syncStateController.close();
  }
}

/// WebDAV 异常
class WebDAVException implements Exception {
  final String message;
  WebDAVException(this.message);

  @override
  String toString() => message;
}
