import 'package:test/test.dart';
import 'package:vaultly_core/vaultly_core.dart';

/// ADR-006 R3 + §3.5 C2：备份负载 v2 与版本闸门
void main() {
  // 用「相对当前时刻」的时间：墓碑保留期是按真实时钟判定的，
  // 写死历史日期会让「新鲜的墓碑」在编码时就被当成超龄清掉。
  final now = DateTime.now();
  final t0 = now.subtract(const Duration(hours: 3));

  LoginEntry login(String id, {DateTime? updatedAt, String? title}) =>
      LoginEntry(
        id: id,
        title: title ?? '条目 $id',
        createdAt: t0,
        updatedAt: updatedAt ?? t0,
        username: 'alice',
        password: 'P@ss!',
      );

  group('v2 负载形状', () {
    test('声明 schemaVersion 2，并把条目放进 vault.entries', () {
      final payload = BackupPayload.encode([login('a')]);

      expect(payload['schemaVersion'], BackupPayload.currentSchema);
      expect(payload['vault'], isA<Map<String, dynamic>>());
      expect(
        (payload['vault'] as Map)[BackupPayload.legacyEntriesKey],
        hasLength(1),
      );
    });

    test('顶层不再暴露 entries —— 旧版本读不到就会拒绝应用（fail-closed）', () {
      final payload = BackupPayload.encode([login('a')]);

      // 这是有意的：≤v4.0.1 只认顶层 entries，而且会静默忽略未知字段。
      // 若沿用同一键名，旧版会把墓碑当正常条目读出来再传回去，
      // 删除就被永久抹掉了。取不到 entries 时旧版会报「格式不正确」并停手。
      expect(payload.containsKey('entries'), isFalse);
    });

    test('墓碑一并上传，超龄墓碑不入包', () {
      final freshTombstone = markEntryDeleted(
        login('gone'),
        at: now.subtract(const Duration(hours: 1)),
      );
      final oldTombstone = markEntryDeleted(
        login('ancient'),
        at: now.subtract(const Duration(days: 45)),
      );

      final payload = BackupPayload.encode([
        login('live'),
        freshTombstone,
        oldTombstone,
      ]);
      final encoded = (payload['vault'] as Map)['entries'] as List;

      expect(encoded, hasLength(2));
      expect(
        encoded.map((e) => (e as Map)['id']),
        containsAll(['live', 'gone']),
      );
      expect(
        encoded.firstWhere((e) => (e as Map)['id'] == 'gone')['deletedAt'],
        isNotNull,
      );
    });
  });

  group('读取兼容（C6）', () {
    test('读得懂 v1 旧备份（顶层 entries，无墓碑）', () {
      final legacy = {
        'version': 1,
        'exportTime': '2026-01-01T00:00:00.000',
        'entries': [login('a').toJson()],
      };

      final contents = BackupPayload.decode(legacy);
      expect(contents.schemaVersion, 1);
      expect(contents.entries.single.id, 'a');
      expect(contents.entries.single.isDeleted, isFalse);
      expect(contents.skipped, 0);
    });

    test('v2 往返保留 deletedAt', () {
      final encoded = BackupPayload.encode([
        login('live'),
        markEntryDeleted(login('gone'), at: t0.add(const Duration(hours: 1))),
      ]);

      final contents = BackupPayload.decode(encoded);
      expect(contents.entries, hasLength(2));
      expect(
        contents.entries.firstWhere((e) => e.id == 'live').isDeleted,
        isFalse,
      );
      expect(
        contents.entries.firstWhere((e) => e.id == 'gone').isDeleted,
        isTrue,
      );
    });

    test('单条坏数据被跳过并计数，不让整份备份打不开', () {
      final payload = BackupPayload.encode([login('a'), login('b')]);
      final encoded = (payload['vault'] as Map)['entries'] as List;
      encoded.insert(1, {'no-type': true});

      final contents = BackupPayload.decode(payload);
      expect(contents.entries, hasLength(2));
      expect(contents.skipped, 1);
    });

    test('既没有 vault.entries 也没有 entries 时抛 FormatException', () {
      expect(
        () => BackupPayload.decode({'schemaVersion': 2}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('版本闸门（C2 fail-closed）', () {
    test('更高的 schemaVersion 直接拒绝，不做「尽力解析」', () {
      expect(
        () => BackupPayload.decode({
          'schemaVersion': BackupPayload.currentSchema + 1,
          'vault': {
            'entries': [login('a').toJson()],
          },
        }),
        throwsA(isA<BackupVersionException>()),
      );
    });

    test('拒绝时带上两边的版本号，便于给出可操作提示', () {
      try {
        BackupPayload.decode({'schemaVersion': 7, 'entries': <dynamic>[]});
        fail('应当抛出 BackupVersionException');
      } on BackupVersionException catch (e) {
        expect(e.found, 7);
        expect(e.supported, BackupPayload.currentSchema);
      }
    });
  });

  group('端到端：删除不会复活', () {
    test('设备 A 删除 → 上传 → 设备 B 合并：条目保持删除', () {
      // 设备 A：先有活跃副本，随后删除（墓碑 updatedAt 更晚）
      final deviceA = [
        markEntryDeleted(login('x'), at: t0.add(const Duration(hours: 1))),
      ];

      final uploaded = BackupPayload.encode(deviceA);
      final received = BackupPayload.decode(uploaded).entries;

      // 设备 B：还留着删除前的旧副本
      final deviceB = [login('x')];
      final merged = mergeVaultEntries(local: deviceB, remote: received);

      expect(merged.entries.single.isDeleted, isTrue);
      expect(merged.remoteDeleted, 1);
    });

    test('旧格式（无墓碑）上传确实会复活——这正是 v2 要解决的问题', () {
      // 对照组：v1 负载里没有删除记录，另一台设备的旧副本必然胜出
      final legacyPayload = {'version': 1, 'entries': <dynamic>[]};
      final received = BackupPayload.decode(legacyPayload).entries;

      final deviceB = [login('x')];
      final merged = mergeVaultEntries(local: deviceB, remote: received);

      expect(merged.entries.single.isDeleted, isFalse);
    });

    test('设备 B 恢复后同步回设备 A：墓碑被清除', () {
      final restored = clearEntryDeletion(
        markEntryDeleted(login('x'), at: t0),
        at: t0.add(const Duration(days: 1)),
      );
      final received = BackupPayload.decode(
        BackupPayload.encode([restored]),
      ).entries;

      final deviceA = [markEntryDeleted(login('x'), at: t0)];
      final merged = mergeVaultEntries(local: deviceA, remote: received);

      expect(merged.entries.single.isDeleted, isFalse);
      expect(merged.remoteRestored, 1);
    });
  });
}
