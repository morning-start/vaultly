import '../vault_entry.dart';
import 'field_based_encryption_strategy.dart';

/// 登录凭证加密策略
///
/// 加密字段：password, totpSecret, notes, username, email
class LoginEncryptionStrategy extends FieldBasedEncryptionStrategy {
  const LoginEncryptionStrategy();

  @override
  Map<String, String> get encryptedFieldMap => const {
    'password': 'passwordEncrypted',
    'totpSecret': 'totpSecretEncrypted',
    'notes': 'notesEncrypted',
    'username': 'usernameEncrypted',
    'email': 'emailEncrypted',
  };

  @override
  String? getFieldValue(VaultEntry entry, String fieldName) {
    final loginEntry = entry as LoginEntry;
    return switch (fieldName) {
      'password' => loginEntry.password,
      'totpSecret' => loginEntry.totpSecret,
      'notes' => loginEntry.notes,
      'username' => loginEntry.username,
      'email' => loginEntry.email,
      _ => null,
    };
  }
}
