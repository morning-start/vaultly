import '../vault_entry.dart';
import 'field_based_encryption_strategy.dart';

/// 银行卡加密策略
///
/// 加密字段：cardNumber, cvv
class BankCardEncryptionStrategy extends FieldBasedEncryptionStrategy {
  const BankCardEncryptionStrategy();

  @override
  Map<String, String> get encryptedFieldMap => const {
    'cardNumber': 'cardNumberEncrypted',
    'cvv': 'cvvEncrypted',
  };

  @override
  String? getFieldValue(VaultEntry entry, String fieldName) {
    final cardEntry = entry as BankCardEntry;
    return switch (fieldName) {
      'cardNumber' => cardEntry.cardNumber,
      'cvv' => cardEntry.cvv,
      _ => null,
    };
  }
}
