import 'dart:typed_data';
import '../vault_entry.dart';

/// 字段级加密策略接口
abstract class EntryEncryptionStrategy {
  /// 加密条目的敏感字段。
  ///
  /// 返回可直接持久化的 JSON：敏感字段替换为 xxxEncrypted 密文，
  /// 明文字段被移除。
  Map<String, dynamic> encryptFields(VaultEntry entry, Uint8List key);

  /// 就地解密持久化 JSON 中的敏感字段。
  ///
  /// [data] 必须是原始持久化 JSON（含 xxxEncrypted 字段），
  /// 解密出的明文写回 [data] 中的原始字段名。
  void decryptFields(Map<String, dynamic> data, Uint8List key);
}
