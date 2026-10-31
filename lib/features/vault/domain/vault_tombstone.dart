import 'vault_entry.dart';

/// 墓碑（回收站）保留期
///
/// ADR-006 §7 开放问题 3：暂定 30 天且不可配置。这个窗口的含义是
/// 「所有设备在 30 天内至少上线同步一次」——超过之后墓碑被物理清除，
/// 某台长期离线的设备再把旧条目带回来时会复活。
const Duration kTombstoneRetention = Duration(days: 30);

/// 标记为已删除（进入回收站）。
///
/// **必须同时刷新 `updatedAt`**：墓碑是靠 LWW 传播的，如果只写
/// `deletedAt` 而不动 `updatedAt`，其他设备上的旧副本会因为时间戳
/// 更「新」而在合并时胜出，删除被静默撤销（ADR-006 R3）。
VaultEntry markEntryDeleted(VaultEntry entry, {DateTime? at}) {
  final timestamp = at ?? DateTime.now();
  return entry.copyWith(deletedAt: timestamp, updatedAt: timestamp);
}

/// 从回收站恢复：清掉墓碑并刷新 `updatedAt`，
/// 这样恢复动作同样能靠 LWW 盖过其他设备上可能存在的墓碑。
VaultEntry clearEntryDeletion(VaultEntry entry, {DateTime? at}) =>
    entry.copyWith(
      clearDeletedAt: true,
      updatedAt: at ?? DateTime.now(),
    );

/// 是否为「已超过保留期」的墓碑（可以物理清除）
bool isExpiredTombstone(VaultEntry entry, {DateTime? now}) {
  final deletedAt = entry.deletedAt;
  if (deletedAt == null) return false;
  return (now ?? DateTime.now()).difference(deletedAt) >= kTombstoneRetention;
}

/// 剔除超龄墓碑；活跃条目与未到期墓碑原样保留。
///
/// 写入本地存储与生成上传负载都走这里，保证两条路径的保留策略一致。
List<VaultEntry> pruneExpiredTombstones(
  List<VaultEntry> entries, {
  DateTime? now,
}) =>
    entries
        .where((entry) => !isExpiredTombstone(entry, now: now))
        .toList();

/// 墓碑的剩余保留天数（向上取整，最小 0），供回收站展示
int tombstoneRemainingDays(VaultEntry entry, {DateTime? now}) {
  final deletedAt = entry.deletedAt;
  if (deletedAt == null) return 0;

  final left = deletedAt.add(kTombstoneRetention).difference(
    now ?? DateTime.now(),
  );
  if (left.isNegative) return 0;
  return (left.inMinutes / (60 * 24)).ceil();
}
