import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/vault/domain/vault_entry.dart';

void main() {
  group('VaultEntry 序列化基线', () {
    test('VaultEntry（custom 类型）toJson/fromJson 往返', () {
      final entry = VaultEntry(
        id: 'e1',
        title: '自定义条目',
        createdAt: DateTime(2026, 1, 1, 12),
        updatedAt: DateTime(2026, 1, 2, 13),
        type: EntryType.custom,
        tags: const ['a', 'b'],
        isFavorite: true,
        folderId: 'f1',
        customFields: [
          CustomField(name: '备注', value: 'v', type: FieldType.text),
        ],
      );

      final restored = VaultEntry.fromJson(entry.toJson());

      expect(restored.id, 'e1');
      expect(restored.title, '自定义条目');
      expect(restored.type, EntryType.custom);
      expect(restored.tags, ['a', 'b']);
      expect(restored.isFavorite, isTrue);
      expect(restored.folderId, 'f1');
      expect(restored.customFields, hasLength(1));
      expect(restored.customFields.first.name, '备注');
    });

    test('LoginEntry 往返保留全部字段', () {
      final entry = LoginEntry(
        id: 'l1',
        title: 'Google',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        username: 'u',
        email: 'e@x.com',
        password: 'p',
        url: 'https://x.com',
        totpSecret: 'SECRET',
        notes: 'n',
      );

      final restored = LoginEntry.fromJson(entry.toJson());

      expect(restored.username, 'u');
      expect(restored.email, 'e@x.com');
      expect(restored.password, 'p');
      expect(restored.url, 'https://x.com');
      expect(restored.totpSecret, 'SECRET');
      expect(restored.notes, 'n');
      expect(restored.type, EntryType.login);
    });

    test('BankCardEntry 往返保留全部字段', () {
      final entry = BankCardEntry(
        id: 'c1',
        title: '招行卡',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        cardNumber: '6222',
        cardHolderName: '张三',
        expiryMonth: 12,
        expiryYear: 2030,
        cvv: '123',
        bankName: 'CMB',
        cardType: CardType.unionPay,
      );

      final restored = BankCardEntry.fromJson(entry.toJson());

      expect(restored.cardNumber, '6222');
      expect(restored.cardHolderName, '张三');
      expect(restored.expiryMonth, 12);
      expect(restored.expiryYear, 2030);
      expect(restored.cvv, '123');
      expect(restored.bankName, 'CMB');
      expect(restored.cardType, CardType.unionPay);
    });

    test('SecureNoteEntry 往返保留全部字段', () {
      final entry = SecureNoteEntry(
        id: 'n1',
        title: '笔记',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        content: '# hello',
        isMarkdown: true,
      );

      final restored = SecureNoteEntry.fromJson(entry.toJson());

      expect(restored.content, '# hello');
      expect(restored.isMarkdown, isTrue);
    });

    test('IdentityEntry 往返保留全部字段', () {
      final entry = IdentityEntry(
        id: 'i1',
        title: '身份',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        firstName: '三',
        lastName: '张',
        middleName: 'M',
        birthDate: DateTime(1990, 5, 1),
        idNumber: 'ID001',
        address: '北京',
        phone: '13800000000',
        email: 'z@x.com',
      );

      final restored = IdentityEntry.fromJson(entry.toJson());

      expect(restored.firstName, '三');
      expect(restored.lastName, '张');
      expect(restored.middleName, 'M');
      expect(restored.birthDate, DateTime(1990, 5, 1));
      expect(restored.idNumber, 'ID001');
      expect(restored.address, '北京');
      expect(restored.phone, '13800000000');
      expect(restored.email, 'z@x.com');
    });

    test('未知 type 字符串回退为 custom（向前兼容）', () {
      final json = VaultEntry(
        id: 'x',
        title: 't',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        type: EntryType.custom,
      ).toJson()
        ..['type'] = 'futureType';

      final restored = VaultEntry.fromJson(json);
      expect(restored.type, EntryType.custom);
    });

    test('tags/customFields/isFavorite 缺省字段有安全默认值', () {
      final restored = VaultEntry.fromJson({
        'id': 'x',
        'title': 't',
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      });

      expect(restored.tags, isEmpty);
      expect(restored.customFields, isEmpty);
      expect(restored.isFavorite, isFalse);
      expect(restored.folderId, isNull);
    });
  });
}
