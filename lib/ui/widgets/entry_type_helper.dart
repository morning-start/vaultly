import 'package:flutter/material.dart';
import '../../core/models/vault_entry.dart';

class EntryTypeHelper {
  static IconData getIcon(EntryType type) {
    return switch (type) {
      EntryType.login => Icons.login,
      EntryType.bankCard => Icons.credit_card,
      EntryType.secureNote => Icons.note,
      EntryType.identity => Icons.person,
      EntryType.custom => Icons.folder,
    };
  }

  static Color getColor(EntryType type) {
    return switch (type) {
      EntryType.login => Colors.blue,
      EntryType.bankCard => Colors.green,
      EntryType.secureNote => Colors.orange,
      EntryType.identity => Colors.purple,
      EntryType.custom => Colors.grey,
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
