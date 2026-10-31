import '../vault_entry.dart';
import 'field_based_encryption_strategy.dart';

/// 身份信息加密策略
///
/// 加密字段：idNumber, phone, email, address
class IdentityEncryptionStrategy extends FieldBasedEncryptionStrategy {
  const IdentityEncryptionStrategy();

  @override
  Map<String, String> get encryptedFieldMap => const {
    'idNumber': 'idNumberEncrypted',
    'phone': 'phoneEncrypted',
    'email': 'emailEncrypted',
    'address': 'addressEncrypted',
  };

  @override
  String? getFieldValue(VaultEntry entry, String fieldName) {
    final identityEntry = entry as IdentityEntry;
    return switch (fieldName) {
      'idNumber' => identityEntry.idNumber,
      'phone' => identityEntry.phone,
      'email' => identityEntry.email,
      'address' => identityEntry.address,
      _ => null,
    };
  }
}
