import 'dart:math';

import 'package:test/test.dart';
import 'package:vaultly_core/vaultly_core.dart';

/// ADR-006 R3 + C5 的性质测试：合并必须确定，删除不得被合并撤销
void main() {
  final t0 = DateTime(2026, 5, 1, 9);

  VaultEntry live(String id, DateTime updated, {String? title}) => VaultEntry(
    id: id,
    title: title ?? '条目 $id',
    createdAt: t0,
    updatedAt: updated,
  );

  VaultEntry dead(String id, DateTime at, {String? title}) => markEntryDeleted(
    VaultEntry(id: id, title: title ?? '条目 $id', createdAt: t0, updatedAt: at),
    at: at,
  );

  /// 条目集合的可比较快照（列表顺序也算，顺序抖动同样是缺陷）
  List<String> snapshot(List<VaultEntry> entries) => entries
      .map(
        (e) =>
            '${e.id}|${e.title}|${e.updatedAt.toIso8601String()}'
            '|${e.deletedAt?.toIso8601String() ?? "-"}',
      )
      .toList();

  /// 忽略顺序的快照（用于「内容未变」类断言，顺序另有专门用例）
  List<String> unorderedSnapshot(List<VaultEntry> entries) =>
      snapshot(entries)..sort();

  group('墓碑 LWW', () {
    test('云端删除较新：本地活跃条目被移入回收站', () {
      final result = mergeVaultEntries(
        local: [live('a', t0)],
        remote: [dead('a', t0.add(const Duration(minutes: 5)))],
      );

      expect(result.entries.single.isDeleted, isTrue);
      expect(result.remoteDeleted, 1);
      expect(result.remoteUpdated, 0);
      expect(result.summary, contains('云端删除 1'));
    });

    test('本地删除较新：云端旧副本不得让条目复活', () {
      final result = mergeVaultEntries(
        local: [dead('a', t0.add(const Duration(hours: 2)))],
        remote: [live('a', t0)],
      );

      expect(result.entries.single.isDeleted, isTrue);
      expect(result.localKept, 1);
      expect(result.hasRemoteChanges, isFalse);
    });

    test('时间戳相同时墓碑优先（删除更保守）', () {
      final result = mergeVaultEntries(
        local: [live('a', t0)],
        remote: [dead('a', t0)],
      );
      expect(result.entries.single.isDeleted, isTrue);

      // 反方向也必须得到同样的结论
      final reversed = mergeVaultEntries(
        local: [dead('a', t0)],
        remote: [live('a', t0)],
      );
      expect(reversed.entries.single.isDeleted, isTrue);
    });

    test('云端恢复较新：本地墓碑被清除（恢复能同步回去）', () {
      final restored = clearEntryDeletion(
        dead('a', t0),
        at: t0.add(const Duration(hours: 1)),
      );
      final result = mergeVaultEntries(
        local: [dead('a', t0)],
        remote: [restored],
      );

      expect(result.entries.single.isDeleted, isFalse);
      expect(result.remoteRestored, 1);
      expect(result.summary, contains('云端恢复 1'));
    });

    test('云端独有墓碑也要加入（用于压制别处的旧副本）', () {
      final result = mergeVaultEntries(
        local: const [],
        remote: [dead('a', t0)],
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.isDeleted, isTrue);
      expect(result.remoteAdded, 1);
    });

    test('双方都是墓碑时保持删除', () {
      final result = mergeVaultEntries(
        local: [dead('a', t0)],
        remote: [dead('a', t0.add(const Duration(minutes: 1)))],
      );
      expect(result.entries.single.isDeleted, isTrue);
    });
  });

  group('C5 性质：确定性', () {
    test('交换律：merge(A,B) 与 merge(B,A) 结果完全一致', () {
      final a = [
        live('a', t0, title: '本地 A'),
        dead('b', t0.add(const Duration(hours: 1))),
        live('c', t0),
        dead('d', t0),
      ];
      final b = [
        live('a', t0, title: '云端 A'),
        live('b', t0),
        dead('c', t0.add(const Duration(hours: 1))),
        live('e', t0),
      ];

      final ab = mergeVaultEntries(local: a, remote: b);
      final ba = mergeVaultEntries(local: b, remote: a);

      // 只有**结果**必须对称；计数天然不对称（它们描述的是「云端那一侧
      // 带来了什么改动」，换个方向就换了一侧）。
      expect(snapshot(ab.entries), snapshot(ba.entries));
      expect(ab.entries, hasLength(ba.entries.length));
    });

    test('幂等：merge(A,A) 不产生任何改动', () {
      final a = [
        live('a', t0),
        dead('b', t0.add(const Duration(hours: 3))),
        live('c', t0.add(const Duration(days: 1))),
      ];

      final result = mergeVaultEntries(local: a, remote: a);

      expect(unorderedSnapshot(result.entries), unorderedSnapshot(a));
      expect(result.hasRemoteChanges, isFalse);
      expect(result.localKept, a.length);
    });

    test('再次合并自己的结果同样稳定（收敛）', () {
      final a = [live('a', t0), dead('b', t0)];
      final b = [live('a', t0.add(const Duration(hours: 1))), live('b', t0)];

      final once = mergeVaultEntries(local: a, remote: b);
      final twice = mergeVaultEntries(local: once.entries, remote: b);
      final thrice = mergeVaultEntries(
        local: twice.entries,
        remote: once.entries,
      );

      expect(snapshot(twice.entries), snapshot(once.entries));
      expect(snapshot(thrice.entries), snapshot(once.entries));
    });

    test('结果排序确定：updatedAt 倒序、同时间按 id 升序', () {
      final same = t0.add(const Duration(hours: 1));
      final result = mergeVaultEntries(
        local: [live('c', same), live('a', same)],
        remote: [live('b', same), live('d', t0)],
      );

      expect(result.entries.map((e) => e.id).toList(), ['a', 'b', 'c', 'd']);
    });

    test('随机语料：交换律 + 幂等 + 删除不被撤销（200 组）', () {
      final random = Random(20261031);
      // 时间戳只从很小的集合里取，制造大量「平局」——这正是旧实现翻车的地方
      final times = [
        t0,
        t0.add(const Duration(minutes: 1)),
        t0.add(const Duration(hours: 1)),
      ];
      final ids = ['a', 'b', 'c', 'd', 'e'];

      List<VaultEntry> corpus() {
        final picked = <String, VaultEntry>{};
        for (final id in ids) {
          if (random.nextBool()) continue;
          final at = times[random.nextInt(times.length)];
          picked[id] = random.nextBool()
              ? live(id, at, title: 'T${random.nextInt(3)}')
              : dead(id, at, title: 'T${random.nextInt(3)}');
        }
        return picked.values.toList();
      }

      for (var round = 0; round < 200; round++) {
        final a = corpus();
        final b = corpus();

        final ab = mergeVaultEntries(local: a, remote: b);
        final ba = mergeVaultEntries(local: b, remote: a);
        expect(
          snapshot(ab.entries),
          snapshot(ba.entries),
          reason: '第 $round 组违反交换律\nA=$a\nB=$b',
        );

        final again = mergeVaultEntries(local: ab.entries, remote: ab.entries);
        expect(
          snapshot(again.entries),
          snapshot(ab.entries),
          reason: '第 $round 组不幂等',
        );

        // 删除不得被撤销：某 id 只要「最新的一次动作是删除」，结果就必须是墓碑
        for (final id in ids) {
          final involved = [...a, ...b].where((e) => e.id == id).toList();
          if (involved.isEmpty) continue;

          final tombstoneMax = involved
              .where((e) => e.isDeleted)
              .map((e) => e.updatedAt)
              .fold<DateTime?>(
                null,
                (max, t) => max == null || t.isAfter(max) ? t : max,
              );
          final liveMax = involved
              .where((e) => !e.isDeleted)
              .map((e) => e.updatedAt)
              .fold<DateTime?>(
                null,
                (max, t) => max == null || t.isAfter(max) ? t : max,
              );

          final expectDeleted =
              tombstoneMax != null &&
              (liveMax == null || !tombstoneMax.isBefore(liveMax));

          expect(
            ab.entries.firstWhere((e) => e.id == id).isDeleted,
            expectDeleted,
            reason: '第 $round 组 id=$id 的删除状态判定错误',
          );
        }
      }
    });
  });
}
