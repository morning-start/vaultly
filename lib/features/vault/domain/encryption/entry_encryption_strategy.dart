import 'dart:typed_data';
import '../vault_entry.dart';

/// 字段级加密策略接口
abstract class EntryEncryptionStrategy {
  /// 加密条目的敏感字段
  Map<String, dynamic> encryptFields(VaultEntry entry, Uint8List key);

  /// 解密条目的敏感字段
  void decryptFields(VaultEntry entry, Map<String, dynamic> data, Uint8List key);
}
