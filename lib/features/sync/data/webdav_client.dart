import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/sync_models.dart';
import 'package:vaultly_core/vaultly_core.dart';

/// 备份解密所需的密钥解析器
///
/// [kdfFromFile] 为备份文件头里的 KDF 参数：
/// - 非 null：新格式（自描述信封），用「主密码 + 文件里的盐值」派生密钥，
///   因此任何设备都能解开；
/// - null：旧格式（无盐纯密文），只能用本机盐值派生的密钥尝试。
typedef BackupKeyResolver = Future<Uint8List> Function(KdfParams? kdfFromFile);

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
      final folderExists = files.any(
        (f) => f.name == _vaultFolderName && f.isDir == true,
      );

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

  /// 上传保险库数据
  ///
  /// 传输固定使用 AES-256-GCM 加密 + GZIP 压缩，服务器只保存密文。
  ///
  /// 格式为「自描述信封」（见 [EncryptedEnvelope]）：KDF 参数（算法、
  /// 盐值、Argon2 强度）和密文写在同一个文件里。盐值不是秘密，它必须
  /// 跟着密文走——否则换设备后同一个主密码会派生出不同的密钥，
  /// 云端备份在新设备上永远解不开。
  ///
  /// 参数:
  /// - [vaultData]: 要上传的保险库数据（内存态明文）
  /// - [encryptionKey]: 加密密钥（由主密码 + [kdfParams] 派生）
  /// - [kdfParams]: 本次加密使用的 KDF 参数，会一并写入文件头
  /// - [onProgress]: 上传进度回调
  Future<bool> upload({
    required Map<String, dynamic> vaultData,
    required Uint8List encryptionKey,
    required KdfParams kdfParams,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw WebDAVException('WebDAV 客户端未初始化');
      }

      await _ensureVaultFolder();

      // Step 1: 序列化为 JSON
      final jsonData = jsonEncode(vaultData);
      debugPrint('WebDAV: 原始数据大小: ${utf8.encode(jsonData).length} bytes');

      // Step 2: 加密为自描述信封
      final envelope = CryptoService.encryptToEnvelope(
        jsonData,
        encryptionKey,
        kdfParams,
      );
      var dataBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(envelope.toJson())),
      );
      debugPrint('WebDAV: 信封大小: ${dataBytes.length} bytes');

      // Step 3: GZIP 压缩
      dataBytes = _gzipCompress(dataBytes);
      debugPrint('WebDAV: 压缩后大小: ${dataBytes.length} bytes');

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileNameEncrypted');
      await tempFile.writeAsBytes(dataBytes);

      await _client!.writeFromFile(
        tempFile.path,
        '/$_vaultFolderName/$_vaultFileNameEncrypted',
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      await tempFile.delete();

      debugPrint('WebDAV: 上传成功（信封格式 v${EncryptedEnvelope.currentVersion}）');

      // 加密上传成功后，清理历史遗留的明文备份，避免明文永久留在服务器。
      // 同时清理旧格式密文：它没有文件头，在新设备上无法解密。
      await _removeIfExists('/$_vaultFolderName/$_vaultFileNamePlain');

      return true;
    } catch (e) {
      debugPrint('WebDAV upload failed: $e');
      if (e is CryptoException) {
        throw WebDAVException('上传失败：本地数据加密失败，请重试');
      }
      throw WebDAVException('上传失败: $e');
    }
  }

  /// 下载并解密保险库数据
  ///
  /// 流程：读取文件 → 解压 → 解析信封文件头 → 用 [keyResolver] 取密钥 → 解密。
  ///
  /// 密钥不在本方法内派生：新格式需要用文件头里的盐值配合主密码重新
  /// 派生（[keyResolver] 会收到文件头的 [KdfParams]），旧格式则退回本机
  /// 会话密钥（此时 [keyResolver] 收到 null）。
  ///
  /// 参数:
  /// - [keyResolver]: 根据文件头参数返回解密密钥
  /// - [onProgress]: 下载进度回调
  ///
  /// 返回 [DownloadedBackup]，其中 [DownloadedBackup.legacyFormat] 标明
  /// 该备份是否为旧的无盐格式（只能在本机读取）。
  Future<DownloadedBackup> download({
    required BackupKeyResolver keyResolver,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw WebDAVException('WebDAV 客户端未初始化');
      }

      await _ensureVaultFolder();

      final files = await _client!.readDir('/$_vaultFolderName');
      final hasBackup = files.any((f) => f.name == _vaultFileNameEncrypted);
      if (!hasBackup) {
        throw WebDAVException('备份文件不存在');
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileNameEncrypted');

      await _client!.read2File(
        '/$_vaultFolderName/$_vaultFileNameEncrypted',
        tempFile.path,
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      final rawBytes = await tempFile.readAsBytes();
      debugPrint('WebDAV: 下载数据大小: ${rawBytes.length} bytes');

      final dataBytes = _maybeGunzip(rawBytes);
      await tempFile.delete();

      final decoded = jsonDecode(utf8.decode(dataBytes));
      if (decoded is! Map<String, dynamic>) {
        throw WebDAVException('备份文件格式无法识别');
      }

      // 新格式：自描述信封，密钥由「主密码 + 文件头盐值」派生
      if (EncryptedEnvelope.isEnvelope(decoded)) {
        final envelope = EncryptedEnvelope.fromJson(decoded);
        final key = await keyResolver(envelope.kdf);
        return DownloadedBackup(
          data: _decryptToMap(
            () => CryptoService.decryptEnvelope(envelope, key),
          ),
        );
      }

      // 旧格式：无文件头的纯密文，盐值只存在于原设备
      if (decoded['cipherText'] is String && decoded['iv'] is String) {
        final legacyData = EncryptedData.fromJson(decoded);
        final key = await keyResolver(null);
        return DownloadedBackup(
          legacyFormat: true,
          data: _decryptToMap(
            () => CryptoService.decrypt(legacyData, key),
            legacy: true,
          ),
        );
      }

      // 历史遗留的明文备份
      return DownloadedBackup(
        data: decoded,
        legacyFormat: true,
        plaintext: true,
      );
    } on WebDAVException {
      rethrow;
    } catch (e) {
      debugPrint('WebDAV download failed: $e');
      throw WebDAVException('下载失败: $e');
    }
  }

  /// 执行解密并解析为 JSON，把「解不开」翻译成用户能看懂的提示
  Map<String, dynamic> _decryptToMap(
    String Function() decrypt, {
    bool legacy = false,
  }) {
    final String jsonData;
    try {
      jsonData = decrypt();
    } on CryptoException {
      if (legacy) {
        // 旧格式没有文件头，盐值只存在于原设备，换个设备无论密码对不对都解不开
        throw WebDAVException(
          '这是一份旧格式备份：文件里不含密钥派生参数，只能在同一台设备上解开。'
          '请在原设备上更新到最新版本并重新上传一次，再用新设备恢复。',
        );
      }
      throw WebDAVException('解密失败：主密码与云端备份不匹配，无法解开这份备份');
    }

    final data = jsonDecode(jsonData);
    if (data is! Map<String, dynamic>) {
      throw WebDAVException('解密失败：备份内容格式不正确');
    }
    return data;
  }

  /// 下载为字节数据（不解析 JSON，保留给诊断用途）
  Future<Uint8List?> downloadAsBytes({
    Function(double progress)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw WebDAVException('WebDAV 客户端未初始化');
      }

      await _ensureVaultFolder();

      final files = await _client!.readDir('/$_vaultFolderName');
      final hasBackup = files.any((f) => f.name == _vaultFileNameEncrypted);
      if (!hasBackup) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$_vaultFileNameEncrypted');

      await _client!.read2File(
        '/$_vaultFolderName/$_vaultFileNameEncrypted',
        tempFile.path,
        onProgress: onProgress != null
            ? (count, total) => onProgress(total > 0 ? count / total : 0)
            : null,
      );

      final dataBytes = await tempFile.readAsBytes();
      await tempFile.delete();

      return _maybeGunzip(dataBytes);
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
      final folderExists = rootFiles.any(
        (f) => f.name == _vaultFolderName && f.isDir == true,
      );
      if (!folderExists) {
        return false;
      }

      final files = await _client!.readDir('/$_vaultFolderName');
      // 检查加密或非加密备份文件
      return files.any(
        (f) =>
            f.name == _vaultFileNameEncrypted || f.name == _vaultFileNamePlain,
      );
    } catch (e) {
      return false;
    }
  }

  /// 列出远程备份格式（加密 / 明文）
  Future<RemoteBackupFormats> listRemoteBackups() async {
    try {
      if (_client == null) return const RemoteBackupFormats();

      final rootFiles = await _client!.readDir('/');
      final folderExists = rootFiles.any(
        (f) => f.name == _vaultFolderName && f.isDir == true,
      );
      if (!folderExists) return const RemoteBackupFormats();

      final files = await _client!.readDir('/$_vaultFolderName');
      return RemoteBackupFormats(
        hasEncrypted: files.any((f) => f.name == _vaultFileNameEncrypted),
        hasPlain: files.any((f) => f.name == _vaultFileNamePlain),
      );
    } catch (e) {
      debugPrint('WebDAV listRemoteBackups failed: $e');
      return const RemoteBackupFormats();
    }
  }

  /// 删除远程文件（不存在则忽略）
  Future<void> _removeIfExists(String path) async {
    try {
      await _client!.remove(path);
      debugPrint('WebDAV: 已清理 $path');
    } catch (_) {
      // 文件本就不存在，忽略
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

  /// 按魔数判断是否需要解压，然后解压
  ///
  /// 历史上压缩开关是可选的，服务器上可能存着未压缩的旧备份；
  /// 靠 0x1f 0x8b 魔数自动识别，比依赖调用方传参更稳。
  Uint8List _maybeGunzip(Uint8List data) {
    if (data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b) {
      return _gzipDecompress(data);
    }
    return data;
  }
}

/// 下载结果
class DownloadedBackup {
  /// 解密后的保险库数据
  final Map<String, dynamic> data;

  /// 是否旧格式（无文件头：密文缺盐，或历史明文备份）
  final bool legacyFormat;

  /// 是否为历史遗留的明文备份
  final bool plaintext;

  const DownloadedBackup({
    required this.data,
    this.legacyFormat = false,
    this.plaintext = false,
  });
}

/// 远程备份格式信息
class RemoteBackupFormats {
  final bool hasEncrypted;
  final bool hasPlain;

  const RemoteBackupFormats({this.hasEncrypted = false, this.hasPlain = false});

  bool get hasAny => hasEncrypted || hasPlain;
}

/// WebDAV 异常
class WebDAVException implements Exception {
  final String message;

  /// 机器可判定的错误码
  ///
  /// 存在的理由：调用方需要区分「可以忽略的失败」（如云端还没有备份）
  /// 与「必须立刻中止的失败」（如备份格式比本应用新）。
  final String? code;

  WebDAVException(this.message, {this.code});

  /// 备份格式版本高于本应用认知（ADR-006 §3.5 C2，fail-closed）
  static const String codeBackupVersionUnsupported =
      'BACKUP_VERSION_UNSUPPORTED';

  @override
  String toString() => message;
}
