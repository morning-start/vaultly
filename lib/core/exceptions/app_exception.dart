/// 应用统一异常基类
///
/// 所有业务异常都应继承此类，便于统一处理和日志记录。
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.originalError});

  /// 用户友好的错误消息
  final String message;

  /// 可选的错误代码，用于程序化错误处理
  final String? code;

  /// 原始异常对象，便于调试
  final Object? originalError;

  @override
  String toString() => '[$runtimeType] $message';
}

/// 认证相关异常
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError});

  /// 账户锁定异常
  factory AuthException.locked(int remainingMinutes) => AuthException(
        '账户已锁定，请在 $remainingMinutes 分钟后重试',
        code: 'AUTH_LOCKED',
      );

  /// 密码错误异常
  factory AuthException.invalidPassword() => const AuthException(
        '密码错误',
        code: 'AUTH_INVALID_PASSWORD',
      );

  /// 生物识别失败异常
  factory AuthException.biometricFailed([String? reason]) => AuthException(
        reason ?? '生物识别验证失败',
        code: 'AUTH_BIOMETRIC_FAILED',
      );

  /// 主密码未设置异常
  factory AuthException.passwordNotSet() => const AuthException(
        '请先设置主密码',
        code: 'AUTH_PASSWORD_NOT_SET',
      );
}

/// 加密服务异常
class CryptoException extends AppException {
  const CryptoException(super.message, {super.code, super.originalError});

  factory CryptoException.encryptionFailed([Object? error]) => CryptoException(
        '数据加密失败',
        code: 'CRYPTO_ENCRYPT_FAILED',
        originalError: error,
      );

  factory CryptoException.decryptionFailed([Object? error]) => CryptoException(
        '数据解密失败，请确认密钥正确',
        code: 'CRYPTO_DECRYPT_FAILED',
        originalError: error,
      );

  factory CryptoException.keyNotSet() => const CryptoException(
        '加密密钥未设置',
        code: 'CRYPTO_KEY_NOT_SET',
      );
}

/// 保险库操作异常
class VaultException extends AppException {
  const VaultException(super.message, {super.code, super.originalError});

  factory VaultException.notFound(String id) => VaultException(
        '条目不存在: $id',
        code: 'VAULT_ENTRY_NOT_FOUND',
      );

  factory VaultException.keyNotSet() => const VaultException(
        '请先解锁保险库',
        code: 'VAULT_KEY_NOT_SET',
      );

  factory VaultException.saveFailed([Object? error]) => VaultException(
        '保存失败',
        code: 'VAULT_SAVE_FAILED',
        originalError: error,
      );
}

/// 同步服务异常
class SyncException extends AppException {
  const SyncException(super.message, {super.code, super.originalError});

  factory SyncException.notConfigured() => const SyncException(
        'WebDAV 未配置',
        code: 'SYNC_NOT_CONFIGURED',
      );

  factory SyncException.connectionFailed([Object? error]) => SyncException(
        '连接失败，请检查网络设置',
        code: 'SYNC_CONNECTION_FAILED',
        originalError: error,
      );

  factory SyncException.uploadFailed([Object? error]) => SyncException(
        '上传失败',
        code: 'SYNC_UPLOAD_FAILED',
        originalError: error,
      );

  factory SyncException.downloadFailed([Object? error]) => SyncException(
        '下载失败',
        code: 'SYNC_DOWNLOAD_FAILED',
        originalError: error,
      );
}

/// 网络相关异常
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});

  factory NetworkException.timeout() => const NetworkException(
        '网络连接超时',
        code: 'NETWORK_TIMEOUT',
      );

  factory NetworkException.noConnection() => const NetworkException(
        '网络不可用，请检查网络连接',
        code: 'NETWORK_NO_CONNECTION',
      );
}
