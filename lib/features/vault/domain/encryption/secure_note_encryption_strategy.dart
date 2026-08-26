import '../vault_entry.dart';
import 'field_based_encryption_strategy.dart';

/// 安全笔记加密策略
///
/// 加密字段：content
class SecureNoteEncryptionStrategy extends FieldBasedEncryptionStrategy {
  const SecureNoteEncryptionStrategy();

  @override
  Map<String, String> get encryptedFieldMap => const {
    'content': 'noteContentEncrypted',
  };

  @override
  String? getFieldValue(VaultEntry entry, String fieldName) {
    if (fieldName == 'content') {
      return (entry as SecureNoteEntry).content;
    }
    return null;
  }
}
