import 'package:test/test.dart';
import 'package:vaultly_core/vaultly_core.dart';

void main() {
  final base = DateTime(2026, 1, 1, 10);

  VaultEntry entry(String id, String title, DateTime updated) =>
      VaultEntry(id: id, title: title, createdAt: base, updatedAt: updated);

  group('mergeVaultEntries 兼容合并', () {
    test('本地独有保留、云端独有加入', () {
      final result = mergeVaultEntries(
        local: [entry('a', '本地A', base)],
        remote: [entry('b', '云端B', base)],
      );

      expect(result.entries.map((e) => e.id), containsAll(['a', 'b']));
      expect(result.remoteAdded, 1);
      expect(result.remoteUpdated, 0);
      expect(result.localKept, 0);
      expect(result.hasRemoteChanges, isTrue);
    });

    test('同 ID 云端较新时覆盖本地', () {
      final result = mergeVaultEntries(
        local: [entry('a', '旧标题', base)],
        remote: [entry('a', '新标题', base.add(const Duration(hours: 1)))],
      );

      expect(result.entries.single.title, '新标题');
      expect(result.remoteUpdated, 1);
      expect(result.localKept, 0);
    });

    test('同 ID 本地较新时保留本地', () {
      final result = mergeVaultEntries(
        local: [entry('a', '本地较新', base.add(const Duration(hours: 2)))],
        remote: [entry('a', '云端较旧', base)],
      );

      expect(result.entries.single.title, '本地较新');
      expect(result.remoteUpdated, 0);
      expect(result.localKept, 1);
      expect(result.hasRemoteChanges, isFalse);
    });

    test('更新时间相同时结果与参数顺序无关（C5 确定性）', () {
      final forward = mergeVaultEntries(
        local: [entry('a', '本地', base)],
        remote: [entry('a', '云端', base)],
      );
      final backward = mergeVaultEntries(
        local: [entry('a', '云端', base)],
        remote: [entry('a', '本地', base)],
      );

      // 旧实现遇到同时间戳「保留本地」，于是两台设备交替同步会来回抖动。
      // 现在由内容指纹裁决：谁胜出都必须与参数顺序无关。
      expect(forward.entries.single.title, backward.entries.single.title);
      expect(forward.entries.single.title, anyOf('本地', '云端'));
    });

    test('更新时间完全相同且内容一致时不产生改动', () {
      final same = entry('a', '同一份内容', base);
      final result = mergeVaultEntries(local: [same], remote: [same]);

      expect(result.localKept, 1);
      expect(result.hasRemoteChanges, isFalse);
    });

    test('云端为空时返回本地全部条目', () {
      final local = [entry('a', 'A', base), entry('b', 'B', base)];
      final result = mergeVaultEntries(local: local, remote: const []);

      expect(result.entries.length, 2);
      expect(result.remoteAdded + result.remoteUpdated, 0);
    });

    test('合并结果按更新时间倒序', () {
      final result = mergeVaultEntries(
        local: [
          entry('a', 'A', base),
          entry('b', 'B', base.add(const Duration(days: 2))),
        ],
        remote: [entry('c', 'C', base.add(const Duration(days: 1)))],
      );

      expect(result.entries.map((e) => e.id).toList(), ['b', 'c', 'a']);
    });

    test('summary 汇总新增/更新/保留数量', () {
      final result = mergeVaultEntries(
        local: [entry('a', 'A', base), entry('b', 'B', base)],
        remote: [
          entry('a', 'A2', base.add(const Duration(hours: 1))),
          entry('c', 'C', base),
          // b：本地更新（时间戳明确更晚，避免落到平局规则上）
          entry('b', 'B2', base.subtract(const Duration(hours: 1))),
        ],
      );

      expect(result.remoteAdded, 1);
      expect(result.remoteUpdated, 1);
      expect(result.localKept, 1);
      expect(result.summary, '云端新增 1 · 云端更新 1 · 保留本地 1');
    });
  });
}
