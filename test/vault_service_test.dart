import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/crypto/services/crypto_service.dart';
import 'package:vaultly/core/models/vault_entry.dart';
import 'package:vaultly/core/services/vault_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultService', () {
    late VaultService vaultService;
    late Uint8List encryptionKey;

    setUp(() {
      vaultService = VaultService();
      encryptionKey = CryptoService.generateKey();
      vaultService.setEncryptionKey(encryptionKey);
    });

    group('基本操作', () {
      test('初始状态应为空', () {
        expect(vaultService.entries, isEmpty);
      });

      test('setEncryptionKey 应设置加密密钥', () {
        final newKey = CryptoService.generateKey();
        vaultService.setEncryptionKey(newKey);
        // 密钥设置成功，后续操作不应抛出异常
        expect(() => vaultService.saveVault(), returnsNormally);
      });

      test('未设置密钥时 saveVault 应抛出异常', () {
        final service = VaultService();
        expect(
          () => service.saveVault(),
          throwsA(isA<VaultException>()),
        );
      });
    });

    group('条目管理', () {
      test('addEntry 应添加条目并返回 UUID', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Test Entry',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          username: 'testuser',
          password: 'testpass',
        );

        final uuid = await vaultService.addEntry(entry);

        expect(uuid, equals('test-id'));
        expect(vaultService.entries.length, equals(1));
        expect(vaultService.entries.first.title, equals('Test Entry'));
      });

      test('getEntry 应返回指定条目', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Test Entry',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await vaultService.addEntry(entry);
        final retrieved = vaultService.getEntry('test-id');

        expect(retrieved, isNotNull);
        expect(retrieved!.title, equals('Test Entry'));
      });

      test('getEntry 对不存在的 ID 应返回 null', () {
        final retrieved = vaultService.getEntry('non-existent');
        expect(retrieved, isNull);
      });

      test('updateEntry 应更新现有条目', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Original Title',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await vaultService.addEntry(entry);

        final updatedEntry = LoginEntry(
          id: 'test-id',
          title: 'Updated Title',
          createdAt: entry.createdAt,
          updatedAt: DateTime.now(),
        );

        await vaultService.updateEntry(updatedEntry);

        final retrieved = vaultService.getEntry('test-id');
        expect(retrieved!.title, equals('Updated Title'));
      });

      test('updateEntry 对不存在的条目应抛出异常', () async {
        final entry = LoginEntry(
          id: 'non-existent',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          () => vaultService.updateEntry(entry),
          throwsA(isA<VaultException>()),
        );
      });

      test('deleteEntry 应删除条目', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Test Entry',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await vaultService.addEntry(entry);
        await vaultService.deleteEntry('test-id');

        expect(vaultService.entries, isEmpty);
      });
    });

    group('条目类型', () {
      test('应支持 LoginEntry', () async {
        final entry = LoginEntry(
          id: 'login-id',
          title: 'Login Entry',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          username: 'user',
          password: 'pass',
          email: 'test@example.com',
          url: 'https://example.com',
          totpSecret: 'JBSWY3DPEHPK3PXP',
          notes: 'Test notes',
        );

        await vaultService.addEntry(entry);
        final retrieved = vaultService.getEntry('login-id');

        expect(retrieved, isA<LoginEntry>());
        expect(retrieved!.title, equals('Login Entry'));
      });

      test('应支持 BankCardEntry', () async {
        final entry = BankCardEntry(
          id: 'card-id',
          title: 'Bank Card',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          cardNumber: '1234567890123456',
          cardHolderName: 'John Doe',
          expiryMonth: 12,
          expiryYear: 2025,
          cvv: '123',
          bankName: 'Test Bank',
          cardType: CardType.visa,
        );

        await vaultService.addEntry(entry);
        final retrieved = vaultService.getEntry('card-id');

        expect(retrieved, isA<BankCardEntry>());
        expect(retrieved!.title, equals('Bank Card'));
      });

      test('应支持 SecureNoteEntry', () async {
        final entry = SecureNoteEntry(
          id: 'note-id',
          title: 'Secure Note',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          content: 'This is a secret note',
          isMarkdown: false,
        );

        await vaultService.addEntry(entry);
        final retrieved = vaultService.getEntry('note-id');

        expect(retrieved, isA<SecureNoteEntry>());
        expect(retrieved!.title, equals('Secure Note'));
      });

      test('应支持 IdentityEntry', () async {
        final entry = IdentityEntry(
          id: 'identity-id',
          title: 'Identity',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          firstName: 'John',
          lastName: 'Doe',
          idNumber: '123456789',
          phone: '1234567890',
          email: 'john@example.com',
          address: '123 Test St',
        );

        await vaultService.addEntry(entry);
        final retrieved = vaultService.getEntry('identity-id');

        expect(retrieved, isA<IdentityEntry>());
        expect(retrieved!.title, equals('Identity'));
      });
    });

    group('搜索和过滤', () {
      setUp(() async {
        await vaultService.addEntry(LoginEntry(
          id: '1',
          title: 'Google Account',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['email', 'work'],
        ));
        await vaultService.addEntry(LoginEntry(
          id: '2',
          title: 'GitHub',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['dev', 'work'],
        ));
        await vaultService.addEntry(BankCardEntry(
          id: '3',
          title: 'Credit Card',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['finance'],
        ));
      });

      test('searchEntries 应按标题搜索', () {
        final results = vaultService.searchEntries('Google');
        expect(results.length, equals(1));
        expect(results.first.id, equals('1'));
      });

      test('searchEntries 应按标签搜索', () {
        final results = vaultService.searchEntries('work');
        expect(results.length, equals(2));
      });

      test('searchEntries 空查询应返回所有条目', () {
        final results = vaultService.searchEntries('');
        expect(results.length, equals(3));
      });

      test('getEntriesByType 应按类型过滤', () {
        final loginEntries = vaultService.getEntriesByType(EntryType.login);
        expect(loginEntries.length, equals(2));

        final cardEntries = vaultService.getEntriesByType(EntryType.bankCard);
        expect(cardEntries.length, equals(1));
      });

      test('getAllEntries 应返回所有条目', () {
        final allEntries = vaultService.getAllEntries();
        expect(allEntries.length, equals(3));
      });
    });

    group('收藏功能', () {
      test('toggleFavorite 应切换收藏状态', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isFavorite: false,
        );

        await vaultService.addEntry(entry);
        await vaultService.toggleFavorite('test-id');

        final retrieved = vaultService.getEntry('test-id');
        expect(retrieved!.isFavorite, isTrue);
      });

      test('getFavorites 应返回所有收藏的条目', () async {
        await vaultService.addEntry(LoginEntry(
          id: '1',
          title: 'Favorite Entry',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isFavorite: true,
        ));
        await vaultService.addEntry(LoginEntry(
          id: '2',
          title: 'Regular Entry',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isFavorite: false,
        ));

        final favorites = vaultService.getFavorites();
        expect(favorites.length, equals(1));
        expect(favorites.first.id, equals('1'));
      });
    });

    group('标签管理', () {
      test('addTag 应添加标签', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: [],
        );

        await vaultService.addEntry(entry);
        await vaultService.addTag('test-id', 'new-tag');

        final retrieved = vaultService.getEntry('test-id');
        expect(retrieved!.tags, contains('new-tag'));
      });

      test('removeTag 应移除标签', () async {
        final entry = LoginEntry(
          id: 'test-id',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['tag1', 'tag2'],
        );

        await vaultService.addEntry(entry);
        await vaultService.removeTag('test-id', 'tag1');

        final retrieved = vaultService.getEntry('test-id');
        expect(retrieved!.tags, isNot(contains('tag1')));
        expect(retrieved.tags, contains('tag2'));
      });

      test('getAllTags 应返回所有唯一标签', () async {
        await vaultService.addEntry(LoginEntry(
          id: '1',
          title: 'Entry 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['tag1', 'tag2'],
        ));
        await vaultService.addEntry(LoginEntry(
          id: '2',
          title: 'Entry 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['tag2', 'tag3'],
        ));

        final allTags = vaultService.getAllTags();
        expect(allTags.length, equals(3));
        expect(allTags, containsAll(['tag1', 'tag2', 'tag3']));
      });
    });
  });
}
