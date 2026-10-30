import '../../vault/domain/vault_entry.dart';

/// 合并统计（用于提示用户本次兼容同步发生了什么）
class VaultMergeResult {
  /// 合并后的条目集合（按更新时间倒序）
  final List<VaultEntry> entries;

  /// 云端独有、已加入本地的条目数
  final int remoteAdded;

  /// 云端较新、覆盖本地同 ID 条目的数量
  final int remoteUpdated;

  /// 本地较新或同时间、保留本地的数量
  final int localKept;

  const VaultMergeResult({
    required this.entries,
    required this.remoteAdded,
    required this.remoteUpdated,
    required this.localKept,
  });

  int get remoteApplied => remoteAdded + remoteUpdated;

  bool get hasRemoteChanges => remoteApplied > 0;

  String get summary =>
      '云端新增 $remoteAdded · 云端更新 $remoteUpdated · 保留本地 $localKept';
}

/// 按条目 ID 合并本地与云端数据（兼容模式）
///
/// 规则（ADR-004 的兼容方案）：
/// - 同一 ID：`updatedAt` 较新的一方生效（last-write-wins）
/// - 仅本地存在：保留
/// - 仅云端存在：加入
/// - 时间完全相同：保留本地，避免无意义的覆盖
///
/// 不做字段级合并，也不删除任何一侧的条目。
VaultMergeResult mergeVaultEntries({
  required List<VaultEntry> local,
  required List<VaultEntry> remote,
}) {
  final byId = <String, VaultEntry>{for (final entry in local) entry.id: entry};

  var remoteAdded = 0;
  var remoteUpdated = 0;
  var localKept = 0;

  for (final remoteEntry in remote) {
    final localEntry = byId[remoteEntry.id];
    if (localEntry == null) {
      byId[remoteEntry.id] = remoteEntry;
      remoteAdded++;
    } else if (remoteEntry.updatedAt.isAfter(localEntry.updatedAt)) {
      byId[remoteEntry.id] = remoteEntry;
      remoteUpdated++;
    } else {
      localKept++;
    }
  }

  final merged = byId.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return VaultMergeResult(
    entries: merged,
    remoteAdded: remoteAdded,
    remoteUpdated: remoteUpdated,
    localKept: localKept,
  );
}
