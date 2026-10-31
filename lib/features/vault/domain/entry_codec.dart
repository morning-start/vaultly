import 'vault_entry.dart';

/// 只取条目的 `type`。
///
/// 持久化 JSON 里 `type` 始终是明文（加密策略要按它选），
/// 因此可以在解密之前安全调用。
EntryType entryTypeFromJson(Map<String, dynamic> json) {
  final typeStr = json['type'] as String?;
  return EntryType.values.firstWhere(
    (e) => e.name == typeStr,
    orElse: () => EntryType.custom,
  );
}

/// 条目 JSON 解析（本地存储与云端备份共用一份）
///
/// 以前这段 `type → 子类` 的分发在两个地方各写了一份
/// （VaultService._entryFromJson 与同步页的 _parseEntryFromJson）。
/// 两份实现一旦漂移就会出现「本地能读、备份读不出」这类难查的问题，
/// 因此收敛到这里。
///
/// [json] 缺少 `type` 时抛 [FormatException]：调用方自己决定是
/// 「整份数据失败」（本地存储，fail-closed）还是「跳过这一条」（备份导入）。
VaultEntry parseVaultEntry(Map<String, dynamic> json) {
  if (json['type'] is! String) {
    throw const FormatException('条目缺少 type 字段');
  }

  return switch (entryTypeFromJson(json)) {
    EntryType.login => LoginEntry.fromJson(json),
    EntryType.bankCard => BankCardEntry.fromJson(json),
    EntryType.secureNote => SecureNoteEntry.fromJson(json),
    EntryType.identity => IdentityEntry.fromJson(json),
    EntryType.custom => VaultEntry.fromJson(json),
  };
}
