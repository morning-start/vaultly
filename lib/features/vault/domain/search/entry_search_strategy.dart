import '../vault_entry.dart';

/// 条目搜索策略接口
///
/// 定义条目搜索的统一接口，不同类型的条目可以实现不同的搜索逻辑。
abstract class EntrySearchStrategy {
  /// 判断条目是否匹配搜索查询
  ///
  /// [entry] 要搜索的条目
  /// [query] 搜索关键词（已转为小写）
  bool matches(VaultEntry entry, String query);
}

/// 基础搜索策略 - 搜索标题和标签
class BasicSearchStrategy implements EntrySearchStrategy {
  const BasicSearchStrategy();

  @override
  bool matches(VaultEntry entry, String query) {
    // 搜索标题
    if (entry.title.toLowerCase().contains(query)) {
      return true;
    }
    // 搜索标签
    if (entry.tags.any((t) => t.toLowerCase().contains(query))) {
      return true;
    }
    return false;
  }
}

/// 登录凭证搜索策略
class LoginEntrySearchStrategy implements EntrySearchStrategy {
  const LoginEntrySearchStrategy();

  @override
  bool matches(VaultEntry entry, String query) {
    final loginEntry = entry as LoginEntry;
    return [
      loginEntry.username,
      loginEntry.email,
      loginEntry.url,
      loginEntry.notes,
    ].any((field) => field?.toLowerCase().contains(query) ?? false);
  }
}

/// 银行卡搜索策略
class BankCardEntrySearchStrategy implements EntrySearchStrategy {
  const BankCardEntrySearchStrategy();

  @override
  bool matches(VaultEntry entry, String query) {
    final cardEntry = entry as BankCardEntry;
    return [
      cardEntry.cardHolderName,
      cardEntry.bankName,
    ].any((field) => field?.toLowerCase().contains(query) ?? false);
  }
}

/// 安全笔记搜索策略
class SecureNoteEntrySearchStrategy implements EntrySearchStrategy {
  const SecureNoteEntrySearchStrategy();

  @override
  bool matches(VaultEntry entry, String query) {
    final noteEntry = entry as SecureNoteEntry;
    return noteEntry.content?.toLowerCase().contains(query) ?? false;
  }
}

/// 身份信息搜索策略
class IdentityEntrySearchStrategy implements EntrySearchStrategy {
  const IdentityEntrySearchStrategy();

  @override
  bool matches(VaultEntry entry, String query) {
    final identityEntry = entry as IdentityEntry;
    return [
      identityEntry.firstName,
      identityEntry.lastName,
      identityEntry.address,
    ].any((field) => field?.toLowerCase().contains(query) ?? false);
  }
}

/// 搜索策略工厂
class SearchStrategyFactory {
  SearchStrategyFactory._();

  static final Map<EntryType, EntrySearchStrategy> _strategies = {
    EntryType.login: const LoginEntrySearchStrategy(),
    EntryType.bankCard: const BankCardEntrySearchStrategy(),
    EntryType.secureNote: const SecureNoteEntrySearchStrategy(),
    EntryType.identity: const IdentityEntrySearchStrategy(),
  };

  /// 获取对应类型的搜索策略
  static EntrySearchStrategy getStrategy(EntryType type) {
    return _strategies[type] ?? const BasicSearchStrategy();
  }
}
