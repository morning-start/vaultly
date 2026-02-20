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
class WebDAVService {
  static const _keyWebDavUrl = 'webdav_url';
  static const _keyWebDavUsername = 'webdav_username';
  static const _keyWebDavPassword = 'webdav_password';
  static const _keyLastSyncTime = 'webdav_last_sync';
  static const _vaultFolderName = 'vaultly';
  static const _vaultFileName = 'vaultly_backup.json';

  final FlutterSecureStorage _secureStorage;
  Client? _client;

  WebDAVService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 检查是否已配置 WebDAV
  Future<bool> isConfigured() async {
    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);
    return url != null &&
        url.isNotEmpty &&
        username != null &&
        password != null;
  }

  /// 获取 WebDAV 配置
  Future<WebDAVConfig?> getConfig() async {
    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);

    if (url == null || username == null || password == null) {
      return null;
    }

    return WebDAVConfig(
      url: url,
      username: username,
      password: password,
    );
  }

  /// 保存 WebDAV 配置
  Future<void> saveConfig(WebDAVConfig config) async {
    await _secureStorage.write(key: _keyWebDavUrl, value: config.url);
    await _secureStorage.write(
        key: _keyWebDavUsername, value: config.username);
    await _secureStorage.write(
        key: _keyWebDavPassword, value: config.password);

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
