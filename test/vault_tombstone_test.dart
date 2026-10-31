import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly_core/vaultly_core.dart';
import 'package:vaultly/features/vault/data/vault_service.dart';

import 'helpers/mock_secure_storage.dart';

/// ADR-006 R3：墓碑生命周期 + 本地存储版本闸门（C2）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;

  setUp(() {
    storage = MockSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    VaultService.reset();
  });

  tearDown(() {
    VaultService.reset();
  });

  VaultEntry login({String id = 'login-1', DateTime? updatedAt}) => LoginEntry(
    id: id,
    title: '登录条目',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    username: 'alice',
    password: 'P@ss!',
  );

  VaultService freshService() =>
      VaultService(secureStorage: const FlutterSecureStorage());

  /// 建一个已解锁、含指定条目的服务
  Future<VaultService> serviceWith(List<VaultEntry> entries) async {
    final service = freshService();
    service.setEncryptionKey(testKey());
    await service.replaceAllEntries(entries);
    return service;
  }

  group('删除 = 墓碑', () {
    test('删除后条目仍在内存与磁盘里，只是带上了 deletedAt', () async {
      final service = await serviceWith([login()]);
      await service.deleteEntry('login-1');

      expect(service.activeEntries, isEmpty);
      expect(service.entries, hasLength(1));
      expect(service.trashedEntries.single.id, 'login-1');

      final json = persistedVaultJson(storage);
      final persisted = (json['entries'] as List).single as Map<String, dynamic>;
      expect(persisted['deletedAt'], isNotNull);
    });

    test('删除必须刷新 updatedAt，否则墓碑赢不过别处的旧副本', () async {
      final service = await serviceWith([login()]);
      await service.deleteEntry('login-1');

      final tombstone = service.entries.single;
      expect(
        tombstone.updatedAt.isAfter(DateTime(2026, 1, 1)),
        isTrue,
        reason: 'updatedAt 不刷新，其他设备上的旧副本会在 LWW 里胜出',
      );
      expect(tombstone.deletedAt, tombstone.updatedAt);
    });

    test('重复删除不会延长保留期（幂等）', () async {
      final service = await serviceWith([login()]);
      await service.deleteEntry('login-1');
      final first = service.entries.single.deletedAt;

      await service.deleteEntry('login-1');
      expect(service.entries.single.deletedAt, first);
    });

    test('恢复清掉墓碑并刷新 updatedAt（恢复也要能同步回去）', () async {
      final service = await serviceWith([login()]);
      await service.deleteEntry('login-1');
      await service.restoreEntry('login-1');

      expect(service.activeEntries, hasLength(1));
      expect(service.trashedEntries, isEmpty);
      expect(service.entries.single.deletedAt, isNull);
    });

    test('彻底删除物理移除，清空回收站只清墓碑', () async {
      final service = await serviceWith([login(id: 'keep'), login(id: 'gone')]);
      await service.deleteEntry('gone');

      expect(await service.purgeAllTrashed(), 1);
      expect(service.entries.map((e) => e.id), ['keep']);
    });
  });

  group('墓碑持久化与保留期', () {
    test('保存 → 重新加载后 deletedAt 仍在（同步要靠它）', () async {
      final service = await serviceWith([login()]);
      await service.deleteEntry('login-1');

      final reloaded = freshService();
      reloaded.setEncryptionKey(testKey());
      await reloaded.loadVault();

      expect(reloaded.entries.single.isDeleted, isTrue);
      expect(reloaded.trashedEntries, hasLength(1));
    });

    test('超龄墓碑在写入时被剔除，且不会被误判为「坏数据」', () async {
      final longAgo = DateTime.now().subtract(const Duration(days: 40));
      await serviceWith([
        login(id: 'live', updatedAt: DateTime.now()),
        markEntryDeleted(login(id: 'old'), at: longAgo),
      ]);

      // 关键回归点：写前回读校验比的是「剔除之后」的条数。
      // 若仍与内存条数比较，每次保存都会被自己的校验拦下。
      final json = persistedVaultJson(storage);
      final persisted = json['entries'] as List;
      expect(persisted, hasLength(1));
      expect((persisted.single as Map)['id'], 'live');

      // 未到期的墓碑必须留下来继续传播删除
      await serviceWith([markEntryDeleted(login())]);
      final freshJson = persistedVaultJson(storage);
      expect(freshJson['entries'] as List, hasLength(1));
    });

    test('purgeExpiredTombstones 按给定时刻清除', () async {
      final deletedAt = DateTime(2026, 6, 1);
      final service = await serviceWith([
        markEntryDeleted(login(), at: deletedAt),
      ]);

      expect(
        await service.purgeExpiredTombstones(now: deletedAt.add(const Duration(days: 10))),
        0,
      );
      expect(
        await service.purgeExpiredTombstones(now: deletedAt.add(const Duration(days: 31))),
        1,
      );
      expect(service.entries, isEmpty);
    });

    test('剩余保留天数向上取整，过期后为 0', () {
      final deletedAt = DateTime(2026, 6, 1, 12);
      final tombstone = markEntryDeleted(login(), at: deletedAt);

      expect(
        tombstoneRemainingDays(tombstone, now: deletedAt),
        kTombstoneRetention.inDays,
      );
      expect(
        tombstoneRemainingDays(tombstone, now: deletedAt.add(const Duration(days: 29, hours: 1))),
        1,
      );
      expect(
        tombstoneRemainingDays(tombstone, now: deletedAt.add(const Duration(days: 31))),
        0,
      );
    });
  });

  group('本地存储版本闸门（C2 fail-closed）', () {
    test('负载写入 schemaVersion', () async {
      final service = await serviceWith([login()]);
      expect(service.entries, hasLength(1));
      expect(
        persistedVaultJson(storage)['schemaVersion'],
        VaultService.currentSchemaVersion,
      );
    });

    test('缺 schemaVersion 的旧负载按 v1 正常读取（C6）', () async {
      final service = await serviceWith([login()]);
      expect(service.entries, hasLength(1));

      final json = persistedVaultJson(storage)..remove('schemaVersion');
      storage.store['vault_data'] = _encode(json);

      final reloaded = freshService();
      reloaded.setEncryptionKey(testKey());
      await reloaded.loadVault();
      expect(reloaded.entries, hasLength(1));
    });

    test('schemaVersion 高于自身时拒绝读取，并且不回退到写前备份', () async {
      // 先制造一份「可用的写前备份」，用来验证它不会被拿来顶替
      final service = await serviceWith([login(id: 'safe')]);
      final safePayload = storage.store['vault_data']!;
      expect(service.entries, hasLength(1));

      // 主区被换成一份未来版本的数据
      final future = persistedVaultJson(storage)
        ..['schemaVersion'] = VaultService.currentSchemaVersion + 1;
      storage.store['vault_data'] = _encode(future);
      storage.store['vault_data.prev'] = safePayload;

      final reloaded = freshService();
      reloaded.setEncryptionKey(testKey());

      await expectLater(
        reloaded.loadVault(),
        throwsA(
          isA<VaultException>().having(
            (e) => e.code,
            'code',
            VaultException.codeSchemaVersionUnsupported,
          ),
        ),
      );

      // 干净地失败：内存态为空、未回退、且不允许写入
      expect(reloaded.entries, isEmpty);
      expect(reloaded.recoveredFromPrevious, isFalse);
      expect(reloaded.isSchemaVersionBlocked, isTrue);
      await expectLater(reloaded.saveVault(), throwsA(isA<VaultException>()));
    });

    test('被版本闸门拦住后，磁盘上的新数据保持原样', () async {
      await serviceWith([login()]);
      final future = persistedVaultJson(storage)
        ..['schemaVersion'] = 99;
      storage.store['vault_data'] = _encode(future);
      final before = storage.store['vault_data'];

      final reloaded = freshService();
      reloaded.setEncryptionKey(testKey());
      try {
        await reloaded.loadVault();
      } on VaultException {
        // 预期
      }

      expect(storage.store['vault_data'], before, reason: '读不懂就绝不能覆盖');
    });

    test('主数据损坏、写前备份也是更高版本时同样拒绝（不回退、不写回）', () async {
      final future = _encode({
        'schemaVersion': 77,
        'entries': <dynamic>[],
      });
      storage.store['vault_data'] = 'not-a-json{{{';
      storage.store['vault_data.prev'] = future;

      final service = freshService();
      service.setEncryptionKey(testKey());

      await expectLater(
        service.loadVault(),
        throwsA(
          isA<VaultException>().having(
            (e) => e.code,
            'code',
            VaultException.codeSchemaVersionUnsupported,
          ),
        ),
      );
      expect(service.entries, isEmpty);
      expect(service.isSchemaVersionBlocked, isTrue);
      await expectLater(service.saveVault(), throwsA(isA<VaultException>()));
    });
  });
}

String _encode(Map<String, dynamic> json) => jsonEncode(json);
