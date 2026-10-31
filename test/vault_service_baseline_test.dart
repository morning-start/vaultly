import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/vault/data/vault_service.dart';
import 'package:vaultly_core/vaultly_core.dart';
import 'package:vaultly/features/vault/domain/vault_notifier.dart';

import 'package:vaultly/features/vault/presentation/vault_providers.dart';

import 'helpers/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;

  setUp(() {
    storage = MockSecureStorage();
    // VaultService 内部持真实 FlutterSecureStorage，
    // 其所有调用委托到静态平台实例 —— 这里整体替换为内存实现。
    FlutterSecureStoragePlatform.instance = storage;
    VaultService.reset();
  });

  tearDown(() {
    VaultService.reset();
  });

  VaultEntry login({String id = 'login-1', String password = 'P@ss!'}) =>
      LoginEntry(
        id: id,
        title: '登录条目',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        username: 'alice',
        password: password,
      );

  VaultService freshService() =>
      VaultService(secureStorage: const FlutterSecureStorage());

  group('VaultService 基线', () {
    test('未设置密钥时 loadVault 抛 VaultException.keyNotSet', () async {
      final service = freshService();
      expect(service.loadVault(), throwsA(isA<Exception>()));
    });

    test('addEntry 后加密持久化，磁盘上无明文 password', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      await service.addEntry(login());

      final json = persistedVaultJson(storage);
      final entries = json['entries'] as List<dynamic>;
      expect(entries, hasLength(1));
      expect(entries.first['password'], isNull, reason: '明文 password 不得落盘');
      expect(entries.first['passwordEncrypted'], isNotNull);
    });

    test('saveVault → 新实例 loadVault roundtrip 恢复原始字段', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      final id = await service.addEntry(login());

      final reloaded = freshService();
      reloaded.setEncryptionKey(testKey());
      await reloaded.loadVault();

      final loaded = await reloaded.getEntry(id);
      expect(loaded, isA<LoginEntry>());
      expect((loaded as LoginEntry).username, 'alice');
      expect(loaded.password, 'P@ss!');
    });

    test('loadVault 空数据时 entries 为空列表且不抛异常', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      await service.loadVault();
      expect(service.entries, isEmpty);
    });

    test('loadVault 遇到损坏数据抛异常（不得静默清空）', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      storage.store['vault_data'] = 'not-a-json{{{';

      await expectLater(service.loadVault(), throwsA(isA<Exception>()));
    });

    test('updateEntry 不存在时抛异常', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      expect(
        service.updateEntry(login(id: 'no-such-id')),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteEntry 移入回收站（墓碑落盘，活跃列表移除）', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      final id = await service.addEntry(login());
      await service.deleteEntry(id);

      // ADR-006 R3：删除不再是物理移除，而是打墓碑继续同步
      expect(service.activeEntries, isEmpty);
      expect(service.entries, hasLength(1));
      expect(service.entries.single.isDeleted, isTrue);
      expect(service.trashedEntries.single.id, id);

      final json = persistedVaultJson(storage);
      final persisted =
          (json['entries'] as List).single as Map<String, dynamic>;
      expect(persisted['deletedAt'], isNotNull);
    });

    test('purgeEntry 物理移除（回收站的彻底删除）', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      final id = await service.addEntry(login());
      await service.deleteEntry(id);
      await service.purgeEntry(id);

      expect(service.entries, isEmpty);
      final json = persistedVaultJson(storage);
      expect((json['entries'] as List), isEmpty);
    });

    test('replaceAllEntries 原子替换', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      await service.replaceAllEntries([login(id: 'a'), login(id: 'b')]);
      expect(service.entries, hasLength(2));
    });
  });

  group('VaultNotifier 基线', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    VaultNotifier notifier() => container.read(vaultNotifierProvider.notifier);

    test('unlock 加载条目，lock 清空内存态', () async {
      final service = freshService();
      service.setEncryptionKey(testKey());
      await service.addEntry(login());

      final n = notifier();
      await n.unlock(testKey());
      expect(container.read(vaultNotifierProvider).isLoaded, isTrue);
      expect(container.read(vaultNotifierProvider).entries, hasLength(1));

      n.lock();
      expect(container.read(vaultNotifierProvider).entries, isEmpty);
      expect(container.read(vaultNotifierProvider).isLoaded, isFalse);
    });

    test('addEntry 成功后 revision 递增且快照刷新', () async {
      final n = notifier();
      await n.unlock(testKey());
      final rev0 = container.read(vaultNotifierProvider).revision;

      final ok = await n.addEntry(login());
      expect(ok, isTrue);
      expect(container.read(vaultNotifierProvider).revision, greaterThan(rev0));
      expect(container.read(vaultNotifierProvider).entries, hasLength(1));
    });

    test('写失败（注入写盘异常）时返回 false、快照回滚、error 置位', () async {
      final n = notifier();
      await n.unlock(testKey());
      final ok = await n.addEntry(login());
      expect(ok, isTrue);
      final snapshotLen = container.read(vaultNotifierProvider).entries.length;

      storage.failNextWrite = true;
      final ok2 = await n.addEntry(login(id: 'login-2'));
      expect(ok2, isFalse);
      expect(container.read(vaultNotifierProvider).error, isNotNull);
      expect(
        container.read(vaultNotifierProvider).entries.length,
        snapshotLen,
        reason: '失败后内存快照必须回滚到写前状态',
      );
    });

    test('rotateKey 用新密钥重加密并持久化', () async {
      final n = notifier();
      await n.unlock(testKey(seed: 42));
      await n.addEntry(login());

      await n.rotateKey(testKey(seed: 99));
      expect(container.read(vaultNotifierProvider).isLoaded, isTrue);

      // 新密钥能解出原始数据
      final reloaded = freshService();
      reloaded.setEncryptionKey(testKey(seed: 99));
      await reloaded.loadVault();
      expect(reloaded.entries, hasLength(1));
    });
  });
}
