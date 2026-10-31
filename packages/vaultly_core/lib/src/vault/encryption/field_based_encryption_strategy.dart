import 'dart:typed_data';
import '../vault_entry.dart';
import 'entry_encryption_strategy.dart';
import '../../crypto/crypto_service.dart';

/// 基于字段的加密策略基类
///
/// 提供通用的字段级加密/解密实现，子类只需声明需要加密的字段映射即可。
/// 大幅减少各策略类中的重复代码。
///
/// 使用方式：
/// ```dart
/// class LoginEncryptionStrategy extends FieldBasedEncryptionStrategy {
///   const LoginEncryptionStrategy();
///
///   @override
///   Map<String, String> get encryptedFieldMap => {
///     'password': 'passwordEncrypted',
///     'totpSecret': 'totpSecretEncrypted',
///     // ...
///   };
/// }
/// ```
abstract class FieldBasedEncryptionStrategy implements EntryEncryptionStrategy {
  const FieldBasedEncryptionStrategy();

  /// 字段映射：原始字段名 -> 加密后字段名
  /// 子类实现此方法，声明哪些字段需要加密
  Map<String, String> get encryptedFieldMap;

  /// 从条目中获取字段值
  /// 子类实现此方法，根据字段名从条目对象中取值
  String? getFieldValue(VaultEntry entry, String fieldName);

  @override
  Map<String, dynamic> encryptFields(VaultEntry entry, Uint8List key) {
    final encrypted = entry.toJson();

    for (final fieldEntry in encryptedFieldMap.entries) {
      final originalField = fieldEntry.key;
      final encryptedField = fieldEntry.value;
      final value = getFieldValue(entry, originalField);

      if (value != null && value.isNotEmpty) {
        encrypted[encryptedField] = CryptoService.encrypt(value, key).toJson();
      }
      // 无论字段是否存在，都必须移除明文字段，
      // 否则明文会与密文一起写入持久化存储（加密形同虚设）。
      encrypted.remove(originalField);
    }

    return encrypted;
  }

  @override
  void decryptFields(Map<String, dynamic> data, Uint8List key) {
    for (final fieldEntry in encryptedFieldMap.entries) {
      final originalField = fieldEntry.key;
      final encryptedField = fieldEntry.value;

      if (data[encryptedField] is Map) {
        final encrypted = EncryptedData.fromJson(
          data[encryptedField] as Map<String, dynamic>,
        );
        // 以密文解出的值为准，覆盖可能残留的旧格式明文字段。
        data[originalField] = CryptoService.decrypt(encrypted, key);
      }
    }
  }
}
