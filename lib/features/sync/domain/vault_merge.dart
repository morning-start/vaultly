import 'dart:convert';

import '../../vault/domain/vault_entry.dart';

/// 合并统计（用于提示用户本次兼容同步发生了什么）
class VaultMergeResult {
  /// 合并后的条目集合（按更新时间倒序，同时间按 id 升序）
  final List<VaultEntry> entries;

  /// 云端独有、已加入本地的条目数（含墓碑）
  final int remoteAdded;

  /// 云端较新且覆盖本地活跃条目的数量
  final int remoteUpdated;

  /// 云端墓碑胜出、把本地条目移入回收站的数量
  final int remoteDeleted;

  /// 云端活跃条目胜出、把本地墓碑恢复的数量
  final int remoteRestored;

  /// 本地较新（或完全相同）、保留本地的数量
  final int localKept;

  const VaultMergeResult({
    required this.entries,
    required this.remoteAdded,
    required this.remoteUpdated,
    required this.remoteDeleted,
    required this.remoteRestored,
    required this.localKept,
  });

  /// 云端带来的实际改动总数
  int get remoteApplied =>
      remoteAdded + remoteUpdated + remoteDeleted + remoteRestored;

  bool get hasRemoteChanges => remoteApplied > 0;

  /// 本次合并让多少条目离开活跃列表（进了回收站）
  int get deletedCount => remoteDeleted;

  String get summary {
    final parts = <String>[
      if (remoteAdded > 0) '云端新增 $remoteAdded',
      if (remoteUpdated > 0) '云端更新 $remoteUpdated',
      if (remoteDeleted > 0) '云端删除 $remoteDeleted',
      if (remoteRestored > 0) '云端恢复 $remoteRestored',
      '保留本地 $localKept',
    ];
    return parts.join(' · ');
  }
}

/// 按条目 ID 合并本地与云端数据（ADR-006 R3 + C5）
///
/// 规则：
/// - 同一 ID：`updatedAt` 较新的一方生效（last-write-wins），**墓碑同等参与**；
///   于是「一方删除、另一方修改」由时间戳决定，删除不再被静默撤销；
/// - 仅本地存在：保留；仅云端存在：加入（云端墓碑也加入，用于压制复活）；
/// - 时间戳相同：墓碑优先（删除更保守），再退到内容指纹做确定性裁决；
/// - 结果排序：`updatedAt` 倒序，同时间按 `id` 升序。
///
/// **确定性（C5）**：`merge(A, B)` 与 `merge(B, A)` 结果必须一致。
/// 因此胜负判定绝不能依赖「谁是 local 参数」——旧实现遇到同时间戳就
/// 「保留本地」，导致两台设备反复同步时结果抖动。
///
/// 不做字段级合并：条目级 LWW 意味着「一端改标题、另一端改密码」会丢一边，
/// 这是当前兼容方案的已知取舍（字段级合并留给 vaultly_core）。
VaultMergeResult mergeVaultEntries({
  required List<VaultEntry> local,
  required List<VaultEntry> remote,
}) {
  final byId = <String, VaultEntry>{for (final entry in local) entry.id: entry};

  var remoteAdded = 0;
  var remoteUpdated = 0;
  var remoteDeleted = 0;
  var remoteRestored = 0;
  var localKept = 0;

  for (final remoteEntry in remote) {
    final localEntry = byId[remoteEntry.id];
    if (localEntry == null) {
      byId[remoteEntry.id] = remoteEntry;
      remoteAdded++;
      continue;
    }

    final winner = pickMergeWinner(local: localEntry, remote: remoteEntry);
    if (identical(winner, localEntry)) {
      localKept++;
      continue;
    }

    byId[remoteEntry.id] = remoteEntry;
    if (remoteEntry.isDeleted && !localEntry.isDeleted) {
      remoteDeleted++;
    } else if (!remoteEntry.isDeleted && localEntry.isDeleted) {
      remoteRestored++;
    } else {
      remoteUpdated++;
    }
  }

  final merged = byId.values.toList()
    ..sort((a, b) {
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });

  return VaultMergeResult(
    entries: merged,
    remoteAdded: remoteAdded,
    remoteUpdated: remoteUpdated,
    remoteDeleted: remoteDeleted,
    remoteRestored: remoteRestored,
    localKept: localKept,
  );
}

/// 判定同 ID 的两个条目哪一方胜出（对称、确定，不依赖参数顺序）
///
/// 返回 [local] 或 [remote] 本身；两者内容完全相同时返回 [local]，
/// 让调用方知道「无需改动」。
VaultEntry pickMergeWinner({
  required VaultEntry local,
  required VaultEntry remote,
}) {
  final byTime = remote.updatedAt.compareTo(local.updatedAt);
  if (byTime != 0) return byTime > 0 ? remote : local;

  // 时间戳撞在一起（多设备时钟可能相同）：删除更保守，墓碑优先
  if (remote.isDeleted != local.isDeleted) {
    return remote.isDeleted ? remote : local;
  }

  // 都活跃或都删除、内容却不同：用内容指纹裁决。
  // 换顺序调用时指纹大小关系不变，因此结果与参数顺序无关（C5）。
  final byContent = _contentFingerprint(remote).compareTo(
    _contentFingerprint(local),
  );
  if (byContent > 0) return remote;
  if (byContent < 0) return local;
  return local;
}

/// 内容指纹：toJson 的键顺序固定，因此同一份内容永远得到同一个字符串。
String _contentFingerprint(VaultEntry entry) => jsonEncode(entry.toJson());
