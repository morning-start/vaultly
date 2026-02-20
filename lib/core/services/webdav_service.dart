import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:path_provider/path_provider.dart';

/// WebDAV 同步服务
///
/// 参考文档: wiki/03-模块设计/同步模块.md
/// 负责与 WebDAV 服务器通信，实现数据同步
/// // 性能优化:
/// - 使用内存缓存减少 SecureStorage 读取
/// - 异步初始化避免阻塞 UI
/// - 批量操作减少 IO 次数
class WebDAVService {
  static const _keyWebDavUrl = 'webdav_url';
  static const _keyWebDavUsername = 'webdav_username';
  static const _keyWebDavPassword = 'webdav_password';
  static const _keyLastSyncTime = 'webdav_last_sync';
  static const _vaultFolderName = 'vaultly';
  static const _vaultFileName = 'vaultly_backup.json';

  final FlutterSecureStorage _secureStorage;
  Client? _client;
  
  // 内存缓存，避免重复读取 SecureStorage
  WebDAVConfig? _cachedConfig;
  bool? _cachedIsConfigured;
  DateTime? _configCacheTime;
  static const _cacheValidityDuration = Duration(seconds: 30);

  WebDAVService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

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

  /// 检查是否已配置 WebDAV
  /// 
  /// 优先使用内存缓存，避免重复读取 SecureStorage
  Future<bool> isConfigured() async {
    // 使用缓存结果
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
    
    // 更新缓存
    _cachedIsConfigured = isConfigured;
    _configCacheTime = DateTime.now();
    
    return isConfigured;
  }

  /// 快速检查是否已配置（同步方法，可能返回过期的缓存结果）
  /// 
  /// 用于 UI 快速响应，实际状态以 isConfigured() 为准
  bool isConfiguredSync() {
    return _cachedIsConfigured ?? false;
  }

  /// 获取 WebDAV 配置
  /// 
  /// 优先使用内存缓存
  Future<WebDAVConfig?> getConfig() async {
    // 使用缓存
    if (_cachedConfig != null && _isCacheValid) {
      return _cachedConfig;
    }

    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);

    if (url == null || username == null || password == null) {
      return null;
    }

    final config = WebDAVConfig(
      url: url,
      username: username,
      password: password,
    );
    
    // 更新缓存
    _cachedConfig = config;
    _configCacheTime = DateTime.now();
    
    return config;
  }

  /// 保存 WebDAV 配置
  Future<void> saveConfig(WebDAVConfig config) async {
    await _secureStorage.write(key: _keyWebDavUrl, value: config.url);
    await _secureStorage.write(
        key: _keyWebDavUsername, value: config.username);
    await _secureStorage.write(
        key: _keyWebDavPassword, value: config.password);

    // 更新缓存
    _cachedConfig = config;
    _cachedIsConfigured = true;
    _configCacheTime = DateTime.now();

    // 重新初始化客户端
    _initClient(config);
  }

  /// 清除 WebDAV 配置
  Future<void> clearConfig() async {
    await _secureStorage.delete(key: _keyWebDavUrl);
    await _secureStorage.delete(key: _keyWebDavUsername);
    await _secureStorage.delete(key: _keyWebDavPassword);
    await _secureStorage.delete(key: _keyLastSyncTime);
    _client = null;
    
    // 清除缓存
    clearCache();
  }

  /// 初始化 WebDAV 客户端
  void _initClient(WebDAVConfig config) {
    _client = newClient(
      config.url,
      user: config.username,
      password: config.password,
    );
  }

  /// 确保 vaultly 文件夹存在，不存在则自动创建
  Future<void> _ensureVaultFolder() async {
    if (_client == null) {
      throw WebDAVException('WebDAV 客户端未初始化');
    }

    try {
      // 检查 vaultly 文件夹是否存在
      final files = await _client!.readDir('/');
      final folderExists = files.any((f) => f.name == _vaultFolderName && f.isDir == true);

      if (!folderExists) {
        // 创建 vaultly 文件夹
        await _client!.mkdir('/$_vaultFolderName');
        debugPrint('WebDAV: 已创建 vaultly 文件夹');
      }
    } catch (e) {
      debugPrint('WebDAV: 创建 vaultly 文件夹失败: $e');
      throw WebDAVException('无法创建 vaultly 文件夹: $e');
    }
  }

  /// 测试连接
  Future<bool> testConnection(WebDAVConfig config) async {
    try {
      final client = newClient(
        config.url,
        user: config.username,
        password: config.password,
      );

      // 尝试 ping 服务器来测试连接
      await client.ping();
      return true;
    } catch (e) {
      debugPrint('WebDAV connection test failed: $e');
      return false;
    }
  }

  /// 上传保险库数据到 WebDAV
  Future<bool> upload({
    required Map<String, dynamic> vaultData,
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

      // 确保 vaultly 文件夹存在
      await _ensureVaultFolder();

      // 将数据转换为 JSON
      final jsonData = jsonEncode(vaultData);
      final bytes = utf8.encode(jsonData);

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileName');
      await tempFile.writeAsBytes(bytes);

      // 上传到 WebDAV 的 vaultly 文件夹
      await _client!.writeFromFile(
        tempFile.path,
        '/$_vaultFolderName/$_vaultFileName',
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      // 更新最后同步时间
      await _secureStorage.write(
        key: _keyLastSyncTime,
        value: DateTime.now().toIso8601String(),
      );

      // 删除临时文件
      await tempFile.delete();

      return true;
    } catch (e) {
      debugPrint('WebDAV upload failed: $e');
      throw WebDAVException('上传失败: $e');
    }
  }

  /// 从 WebDAV 下载保险库数据
  Future<Map<String, dynamic>?> download({
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

      // 确保 vaultly 文件夹存在
      await _ensureVaultFolder();

      // 检查文件是否存在
      final files = await _client!.readDir('/$_vaultFolderName');
      final hasBackup = files.any((f) => f.name == _vaultFileName);
      if (!hasBackup) {
        throw WebDAVException('备份文件不存在');
      }

      // 下载到临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileName');

      await _client!.read2File(
        '/$_vaultFolderName/$_vaultFileName',
        tempFile.path,
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      // 读取并解析数据
      final jsonData = await tempFile.readAsString();
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // 删除临时文件
      await tempFile.delete();

      // 更新最后同步时间
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
  /// 
  /// 注意: 这是一个网络操作，可能耗时较长
  Future<bool> checkRemoteBackup() async {
    try {
      final config = await getConfig();
      if (config == null) return false;

      if (_client == null) {
        _initClient(config);
      }

      // 检查 vaultly 文件夹是否存在
      final rootFiles = await _client!.readDir('/');
      final folderExists = rootFiles.any((f) => f.name == _vaultFolderName && f.isDir == true);
      if (!folderExists) {
        return false;
      }

      // 检查 vaultly 文件夹内是否有备份文件
      final files = await _client!.readDir('/$_vaultFolderName');
      return files.any((f) => f.name == _vaultFileName);
    } catch (e) {
      return false;
    }
  }
}

/// WebDAV 配置
class WebDAVConfig {
  final String url;
  final String username;
  final String password;

  WebDAVConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  WebDAVConfig copyWith({
    String? url,
    String? username,
    String? password,
  }) {
    return WebDAVConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

/// WebDAV 异常
class WebDAVException implements Exception {
  final String message;
  WebDAVException(this.message);

  @override
  String toString() => message;
}