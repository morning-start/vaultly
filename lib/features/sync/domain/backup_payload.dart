import '../../vault/domain/entry_codec.dart';
import '../../vault/domain/vault_entry.dart';
import '../../vault/domain/vault_tombstone.dart';

/// 备份负载版本高于本应用认知时抛出
///
/// 调用方**必须**把它翻译成对用户可见的错误并中止本次操作，
/// 绝不能「尽力解析」——读不懂就写回，等于静默销毁数据（C2）。
class BackupVersionException implements Exception {
  /// 备份声明的版本
  final int found;

  /// 本应用支持的版本
  final int supported;

  const BackupVersionException({required this.found, required this.supported});

  @override
  String toString() => '备份格式 v$found 高于本应用支持的 v$supported';
}

/// 解析结果
class BackupContents {
  /// 解出的条目（含墓碑）
  final List<VaultEntry> entries;

  /// 读不出来被跳过的条目数（>0 时 UI 必须告知用户，不能静默吞掉）
  final int skipped;

  /// 备份声明的格式版本
  final int schemaVersion;

  const BackupContents({
    required this.entries,
    required this.schemaVersion,
    this.skipped = 0,
  });
}

/// 云端备份负载（信封**内层**明文）的读写
///
/// ## 两个版本
/// - **v1（历史，≤v4.0.1）**：`{version: 1, exportTime, entries: [...]}`。
///   删除即物理删除，没有墓碑——任何一次合并都会让别处删掉的条目复活。
/// - **v2（ADR-006 R3）**：`{schemaVersion: 2, exportTime, vault: {entries: [...]}}`。
///   `vault.entries` 里**含墓碑**（带 `deletedAt` 的条目）。
///
/// ## 为什么 v2 换了外层键名（`entries` → `vault.entries`）
/// 旧版本读备份时只认 `data['entries']`，而 `fromJson` 又会静默忽略
/// 不认识的字段。如果 v2 把墓碑写在同一个 `entries` 里，旧版会
/// 「看不见 deletedAt 却照单全收」：把已删除的条目当正常条目显示出来，
/// 再上传一次就把删除彻底抹掉（ADR-006 §10 F5 描述的正是这个事故）。
///
/// 改成嵌套键之后，旧版取 `data['entries']` 得到 null，会直接报
/// 「下载的数据为空或格式不正确」并**拒绝应用这份备份**。
/// 旧版本改不了，但至少它不会静默损坏数据——这就是 C2 要的 fail-closed。
/// 代价：升级本版本的当天，必须把所有设备都升级（§5 版本窗口规则）。
///
/// ## 读取侧兼容（C6）
/// 旧备份必须仍然能打开：缺 `schemaVersion` 时按 v1 处理，
/// 并回退到顶层的 `entries` 键。
class BackupPayload {
  /// 当前写入的格式版本
  static const int currentSchema = 2;

  /// v1 的顶层条目键
  static const String legacyEntriesKey = 'entries';

  /// v2 的嵌套容器键
  static const String vaultKey = 'vault';

  /// 生成上传负载（含墓碑，已剔除超龄墓碑）
  static Map<String, dynamic> encode(
    List<VaultEntry> entries, {
    DateTime? now,
  }) {
    final retained = pruneExpiredTombstones(entries, now: now);

    return {
      'schemaVersion': currentSchema,
      'exportTime': (now ?? DateTime.now()).toIso8601String(),
      vaultKey: {
        legacyEntriesKey: retained.map((e) => e.toJson()).toList(),
      },
    };
  }

  /// 解析下载到的负载
  ///
  /// 版本高于 [currentSchema] 时抛 [BackupVersionException]（fail-closed）。
  /// 单条条目的解析失败会被跳过并计数，而不是让整份备份打不开。
  static BackupContents decode(Map<String, dynamic> data) {
    final version =
        data['schemaVersion'] as int? ?? data['version'] as int? ?? 1;
    if (version > currentSchema) {
      throw BackupVersionException(found: version, supported: currentSchema);
    }

    final raw = _rawEntries(data);
    if (raw == null) {
      throw const FormatException('备份里没有条目列表');
    }

    final entries = <VaultEntry>[];
    var skipped = 0;
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      try {
        entries.add(parseVaultEntry(item));
      } catch (_) {
        // 单条损坏不该让整份备份打不开；计数后由 UI 告知用户
        skipped++;
      }
    }

    return BackupContents(
      entries: entries,
      schemaVersion: version,
      skipped: skipped,
    );
  }

  static List<dynamic>? _rawEntries(Map<String, dynamic> data) {
    final nested = data[vaultKey];
    if (nested is Map<String, dynamic>) {
      final entries = nested[legacyEntriesKey];
      if (entries is List) return entries;
    }

    final legacy = data[legacyEntriesKey];
    if (legacy is List) return legacy;

    return null;
  }
}
