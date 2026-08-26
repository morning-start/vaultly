import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/sync_models.dart';
import '../../../features/auth/data/crypto_service.dart';

/// WebDAV 纯网络客户端
///
/// 只关心 HTTP 请求和文件系统操作，不涉及配置持久化。
class WebDAVClient {
  static const _vaultFolderName = 'vaultly';
  static const _vaultFileNameEncrypted = 'vaultly_backup.enc';
  static const _vaultFileNamePlain = 'vaultly_backup.json';

  Client? _client;

  /// 初始化 WebDAV 客户端
  void initClient(SyncConfig config) {
    _client = newClient(
      config.serverUrl,
      user: config.username,
      password: config.password ?? '',
    );
  }

  /// 清除客户端配置
  void clearConfig() {
    _client = null;
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

  /// 创建目录
  Future<void> createDirectory(String path) async {
    if (_client == null) {
      throw WebDAVException('WebDAV 客户端未初始化');
    }
    await _client!.mkdir(path);
  }

  /// 检查远程路径是否存在
  Future<bool> exists(String path) async {
    if (_client == null) {
      throw WebDAVException('WebDAV 客户端未初始化');
    }
    try {
      await _client!.readDir(path);
      return true;
    } catch (_) {
      return false;
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

  /// 上传保险库数据（支持加密/不加密模式）
  ///
  /// 加密模式流程（默认）：
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
  /// 非加密模式流程：
  /// ```
  /// JSON 数据
  ///      ↓
  /// GZIP 压缩（可选）
  ///      ↓
  /// WebDAV 服务器（存储原始 JSON）
  /// ```
  ///
  /// 参数:
  /// - [vaultData]: 要上传的保险库数据
  /// - [encryptionKey]: 加密密钥（由主密码派生）
  /// - [enableEncryption]: 是否启用加密（默认 true）
  /// - [enableCompression]: 是否启用 GZIP 压缩（默认 true）
  /// - [onProgress]: 上传进度回调
  Future<bool> upload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw WebDAVException('WebDAV 客户端未初始化');
      }

      await _ensureVaultFolder();

      // Step 1: 序列化为 JSON
      final jsonData = jsonEncode(vaultData);
      var dataBytes = Uint8List.fromList(utf8.encode(jsonData));
      debugPrint('WebDAV: 原始数据大小: ${dataBytes.length} bytes');

      // Step 2: 根据配置决定是否加密
      if (enableEncryption) {
        final encryptedData = CryptoService.encrypt(jsonData, encryptionKey);
        final encryptedJson = jsonEncode(encryptedData.toJson());
        dataBytes = Uint8List.fromList(utf8.encode(encryptedJson));
        debugPrint('WebDAV: 加密后大小: ${dataBytes.length} bytes');
      }

      // Step 3: 根据配置决定是否压缩
      if (enableCompression) {
        dataBytes = _gzipCompress(dataBytes);
        debugPrint('WebDAV: 压缩后大小: ${dataBytes.length} bytes');
      }

      // 根据是否加密选择文件名
      final fileName = enableEncryption ? _vaultFileNameEncrypted : _vaultFileNamePlain;

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(dataBytes);

      await _client!.writeFromFile(
        tempFile.path,
        '/$_vaultFolderName/$fileName',
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      await tempFile.delete();

      debugPrint('WebDAV: 上传成功 (${enableEncryption ? '加密' : '未加密'})');

      return true;
    } catch (e) {
      debugPrint('WebDAV upload failed: $e');
      throw WebDAVException('上传失败: $e');
    }
  }

  /// 下载保险库数据（支持解密/不解密模式）
  ///
  /// 解密模式流程（默认）：
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
  /// 非解密模式流程：
  /// ```
  /// WebDAV 服务器
  ///      ↓
  /// GZIP 解压（可选）
  ///      ↓
  /// JSON 解析
  ///      ↓
  /// 保险库数据
  /// ```
  ///
  /// 参数:
  /// - [encryptionKey]: 解密密钥（由主密码派生）
  /// - [enableEncryption]: 是否启用解密（默认 true）
  /// - [enableCompression]: 是否启用 GZIP 解压（默认 true）
  /// - [onProgress]: 下载进度回调
  Future<Map<String, dynamic>?> download({
    required Uint8List encryptionKey,
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw WebDAVException('WebDAV 客户端未初始化');
      }

      await _ensureVaultFolder();

      // 根据是否加密选择文件名
      final fileName = enableEncryption ? _vaultFileNameEncrypted : _vaultFileNamePlain;

      final files = await _client!.readDir('/$_vaultFolderName');
      final hasBackup = files.any((f) => f.name == fileName);
      if (!hasBackup) {
        throw WebDAVException('备份文件不存在');
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$fileName');

      await _client!.read2File(
        '/$_vaultFolderName/$fileName',
        tempFile.path,
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      // Step 1: 读取数据
      var dataBytes = await tempFile.readAsBytes();
      debugPrint('WebDAV: 下载数据大小: ${dataBytes.length} bytes');

      // Step 2: 根据配置决定是否解压
      if (enableCompression) {
        dataBytes = _gzipDecompress(dataBytes);
        debugPrint('WebDAV: 解压后大小: ${dataBytes.length} bytes');
      }

      // Step 3: 根据配置决定是否解密
      String jsonData;
      if (enableEncryption) {
        final encryptedJson = utf8.decode(dataBytes);
        final encryptedData = EncryptedData.fromJson(
          jsonDecode(encryptedJson) as Map<String, dynamic>
        );
        jsonData = CryptoService.decrypt(encryptedData, encryptionKey);
        debugPrint('WebDAV: 解密成功');
      } else {
        jsonData = utf8.decode(dataBytes);
      }

      // Step 4: 反序列化为 JSON
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      await tempFile.delete();

      return data;
    } catch (e) {
      debugPrint('WebDAV download failed: $e');
      throw WebDAVException('下载失败: $e');
    }
  }

  /// 下载为字节数据（不解析 JSON）
  Future<Uint8List?> downloadAsBytes({
    bool enableEncryption = true,
    bool enableCompression = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw WebDAVException('WebDAV 客户端未初始化');
      }

      await _ensureVaultFolder();

      final fileName = enableEncryption ? _vaultFileNameEncrypted : _vaultFileNamePlain;

      final files = await _client!.readDir('/$_vaultFolderName');
      final hasBackup = files.any((f) => f.name == fileName);
      if (!hasBackup) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$fileName');

      await _client!.read2File(
        '/$_vaultFolderName/$fileName',
        tempFile.path,
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      var dataBytes = await tempFile.readAsBytes();

      if (enableCompression) {
        dataBytes = _gzipDecompress(dataBytes);
      }

      await tempFile.delete();

      return dataBytes;
    } catch (e) {
      debugPrint('WebDAV downloadAsBytes failed: $e');
      throw WebDAVException('下载失败: $e');
    }
  }

  /// 检查远程备份是否存在
  ///
  /// 自动检测加密和非加密备份文件
  Future<bool> checkRemoteBackup() async {
    try {
      if (_client == null) return false;

      final rootFiles = await _client!.readDir('/');
      final folderExists = rootFiles.any((f) => f.name == _vaultFolderName && f.isDir == true);
      if (!folderExists) {
        return false;
      }

      final files = await _client!.readDir('/$_vaultFolderName');
      // 检查加密或非加密备份文件
      return files.any((f) =>
        f.name == _vaultFileNameEncrypted ||
        f.name == _vaultFileNamePlain
      );
    } catch (e) {
      return false;
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
}

/// WebDAV 异常
class WebDAVException implements Exception {
  final String message;
  WebDAVException(this.message);

  @override
  String toString() => message;
}
