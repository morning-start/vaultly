import 'package:flutter/material.dart';
import '../../../../ui/theme/vaultly_colors.dart';
import 'package:vaultly_core/vaultly_core.dart';

/// 条目类型静态辅助：图标与名称
///
/// 颜色已迁移至主题扩展 [VaultlyColors]（明暗自适应），
/// 使用方式：`Theme.of(context).colorScheme.entryType(type)`。
class EntryTypeHelper {
  static IconData getIcon(EntryType type) {
    return switch (type) {
      EntryType.login => Icons.key_rounded,
      EntryType.bankCard => Icons.credit_card_rounded,
      EntryType.secureNote => Icons.sticky_note_2_rounded,
      EntryType.identity => Icons.person_rounded,
      EntryType.custom => Icons.folder_rounded,
    };
  }

  static String getName(EntryType type) {
    return switch (type) {
      EntryType.login => '登录凭证',
      EntryType.bankCard => '银行卡',
      EntryType.secureNote => '安全笔记',
      EntryType.identity => '身份信息',
      EntryType.custom => '自定义',
    };
  }

  static String getCardTypeName(CardType type) {
    return switch (type) {
      CardType.visa => 'Visa',
      CardType.mastercard => 'Mastercard',
      CardType.amex => 'American Express',
      CardType.discover => 'Discover',
      CardType.jcb => 'JCB',
      CardType.unionPay => 'UnionPay',
      CardType.other => '其他',
    };
  }
}
