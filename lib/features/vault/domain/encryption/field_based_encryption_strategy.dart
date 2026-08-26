import 'dart:typed_data';
import '../../../auth/data/crypto_service.dart';
import '../vault_entry.dart';
import 'entry_encryption_strategy.dart';

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
    }

    return encrypted;
  }

  @override
  void decryptFields(VaultEntry entry, Map<String, dynamic> data, Uint8List key) {
    for (final entry in encryptedFieldMap.entries) {
      final originalField = entry.key;
      final encryptedField = entry.value;

      if (data[encryptedField] is Map) {
        final encrypted = EncryptedData.fromJson(data[encryptedField] as Map<String, dynamic>);
        data[originalField] = CryptoService.decrypt(encrypted, key);
      }
    }
  }
}
