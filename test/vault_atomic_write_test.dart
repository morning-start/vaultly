import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly_core/vaultly_core.dart';
import 'package:vaultly/features/vault/data/vault_service.dart';

import 'helpers/mock_secure_storage.dart';

/// R0：存储写入加固（写前备份 + 原子写）
///
/// 契约：
/// - 主存储区**最后**写入，因此写入过程中的任何失败都不会破坏它
/// - `.prev` 始终是一份可读的完整数据（用于主数据损坏时回退）
/// - 主数据损坏时**不得**用坏数据覆盖好的 `.prev`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;

  const mainKey = 'vault_data';
  const prevKey = 'vault_data.prev';

  setUp(() {
    storage = MockSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    VaultService.reset();
  });

  tearDown(VaultService.reset);

  VaultEntry login(String id) => LoginEntry(
    id: id,
    title: '条目 $id',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    username: 'user-$id',
    password: 'secret-$id',
  );

  VaultService freshService() {
    final service = VaultService(secureStorage: const FlutterSecureStorage());
    service.setEncryptionKey(testKey());
    return service;
  }

  int entryCountOf(String? raw) {
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    return (decoded['entries'] as List<dynamic>).length;
  }

  group('正常写入', () {
    test('保存后主数据与写前备份都应存在', () async {
      final service = freshService();
      await service.addEntry(login('a'));

      expect(storage.store[mainKey], isNotNull);
      expect(storage.store[prevKey], isNotNull, reason: '首次保存也要有可回退的副本');
      expect(entryCountOf(storage.store[mainKey]), equals(1));
    });

    test('第二次保存后 .prev 应等于上一次的主数据', () async {
      final service = freshService();
      await service.addEntry(login('a'));
      final firstMain = storage.store[mainKey];

      await service.addEntry(login('b'));

      expect(storage.store[prevKey], equals(firstMain));
      expect(entryCountOf(storage.store[mainKey]), equals(2));
      expect(entryCountOf(storage.store[prevKey]), equals(1));
    });

    test('写前备份可被独立加载（回退副本自身必须是完整可读的）', () async {
      final service = freshService();
      await service.addEntry(login('a'));
      await service.addEntry(login('b'));

      // 把 .prev 当作主数据来加载，应当成功
      storage.store[mainKey] = storage.store[prevKey]!;
      VaultService.reset();
      final reloaded = freshService();
      await reloaded.loadVault();

      expect(reloaded.recoveredFromPrevious, isFalse);
      expect(reloaded.entries.length, equals(1));
    });
  });

  group('写入失败', () {
    test('写入过程中失败时主数据必须保持不变', () async {
      final service = freshService();
      await service.addEntry(login('a'));
      final mainBefore = storage.store[mainKey];

      // 下一次写（写前备份那一步）失败
      storage.failNextWrite = true;
      await expectLater(service.addEntry(login('b')), throwsA(anything));

      expect(
        storage.store[mainKey],
        equals(mainBefore),
        reason: '主存储区最后才写，前面的失败不应动到它',
      );
    });

    test('失败后重新保存应能正常写入', () async {
      final service = freshService();
      await service.addEntry(login('a'));

      storage.failNextWrite = true;
      await expectLater(service.addEntry(login('b')), throwsA(anything));

      storage.failNextWrite = false;
      await service.saveVault();

      expect(entryCountOf(storage.store[mainKey]), equals(2));
    });
  });

  group('主数据损坏', () {
    test('应自动回退到写前备份并置位提示标志', () async {
      final service = freshService();
      await service.addEntry(login('a'));
      await service.addEntry(login('b'));
      expect(service.entries.length, equals(2));

      // 破坏主数据（模拟写坏/解析失败）
      storage.store[mainKey] = '{ 这不是合法 JSON';
      VaultService.reset();
      final reloaded = freshService();
      await reloaded.loadVault();

      expect(reloaded.recoveredFromPrevious, isTrue);
      expect(reloaded.entries.length, equals(1), reason: '回退到的是上一次成功写入的版本');
      expect(reloaded.entries.first.id, equals('a'));
    });

    test('正常加载时不应置位提示标志', () async {
      final service = freshService();
      await service.addEntry(login('a'));

      VaultService.reset();
      final reloaded = freshService();
      await reloaded.loadVault();

      expect(reloaded.recoveredFromPrevious, isFalse);
    });

    test('主数据不可解密时同样回退（不是只有 JSON 坏了才回退）', () async {
      // 1) 用本机密钥存一份数据，留下写前备份
      final service = freshService();
      await service.addEntry(login('a'));
      final localBackup = storage.store[prevKey]!;

      // 2) 用另一把密钥生成一份「JSON 合法但解不开」的密文
      VaultService.reset();
      final foreign = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(testKey(seed: 7));
      await foreign.addEntry(login('x'));
      final foreignPayload = storage.store[mainKey]!;

      // 3) 还原成本机场景：主数据是外来密文，写前备份是本机数据
      storage.store[mainKey] = foreignPayload;
      storage.store[prevKey] = localBackup;

      VaultService.reset();
      final reloaded = freshService();
      await reloaded.loadVault();

      expect(
        reloaded.recoveredFromPrevious,
        isTrue,
        reason: '解密失败也必须走回退，不能直接判成数据丢失',
      );
      expect(reloaded.entries.first.id, equals('a'));
    });

    test('回退后保存不得用坏数据覆盖写前备份', () async {
      final service = freshService();
      await service.addEntry(login('a'));
      await service.addEntry(login('b'));

      storage.store[mainKey] = 'garbage';
      VaultService.reset();
      final reloaded = freshService();
      await reloaded.loadVault();
      expect(reloaded.recoveredFromPrevious, isTrue);

      await reloaded.addEntry(login('c'));

      // .prev 必须仍是可读的完整数据（a + c），而不是那份坏数据
      expect(entryCountOf(storage.store[prevKey]), equals(2));
      expect(entryCountOf(storage.store[mainKey]), equals(2));
    });

    test('主数据与写前备份都损坏时应抛异常而不是静默清空', () async {
      storage.store[mainKey] = 'garbage';
      storage.store[prevKey] = 'garbage too';

      final service = freshService();

      await expectLater(service.loadVault(), throwsA(isA<VaultException>()));
    });
  });
}
