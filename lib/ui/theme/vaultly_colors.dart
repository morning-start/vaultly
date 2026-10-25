import 'package:flutter/material.dart';

import '../../features/vault/domain/vault_entry.dart';

/// Vaultly 专属色彩扩展
///
/// 条目类型色与收藏色纳入主题体系，按明暗自适应（Tailwind 600/400 双档），
/// 取代原先 `EntryTypeHelper` 中硬编码的 `Colors.blue/green/...`。
///
/// 用法：`Theme.of(context).extension<VaultlyColors>()!.login`
extension VaultlyColors on ColorScheme {
  /// 登录凭证（Sky 600 / 400）
  Color get login => brightness == Brightness.light
      ? const Color(0xFF0284C7)
      : const Color(0xFF38BDF8);

  /// 银行卡（Emerald 600 / 400）
  Color get bankCard => brightness == Brightness.light
      ? const Color(0xFF059669)
      : const Color(0xFF34D399);

  /// 安全笔记（Amber 600 / 400）
  Color get secureNote => brightness == Brightness.light
      ? const Color(0xFFD97706)
      : const Color(0xFFFBBF24);

  /// 身份信息（Violet 600 / 400）
  Color get identity => brightness == Brightness.light
      ? const Color(0xFF7C3AED)
      : const Color(0xFFA78BFA);

  /// 自定义（Slate 500 / 400）
  Color get custom => brightness == Brightness.light
      ? const Color(0xFF64748B)
      : const Color(0xFF94A3B8);

  /// 收藏星标（Amber 500 / 400）
  Color get favorite => brightness == Brightness.light
      ? const Color(0xFFF59E0B)
      : const Color(0xFFFBBF24);

  /// 按类型取色
  Color entryType(EntryType type) {
    return switch (type) {
      EntryType.login => login,
      EntryType.bankCard => bankCard,
      EntryType.secureNote => secureNote,
      EntryType.identity => identity,
      EntryType.custom => custom,
    };
  }
}
