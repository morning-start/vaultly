import 'package:test/test.dart';
import 'package:vaultly_core/vaultly_core.dart';

void main() {
  group('FieldBasedEncryptionStrategy 加密往返', () {
    final key = CryptoService.generateKey();

    test('加密后 JSON 不得包含明文 password 字段', () {
      final entry = LoginEntry(
        id: 'test-id',
        title: '测试登录',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        username: 'alice',
        email: 'alice@example.com',
        password: 'SuperSecret123!',
        totpSecret: 'JBSWY3DPEHPK3PXP',
        notes: 'secret note',
      );

      final encrypted = const LoginEncryptionStrategy().encryptFields(
        entry,
        key,
      );

      // 明文字段必须被移除，否则加密形同虚设
      expect(
        encrypted.containsKey('password'),
        isFalse,
        reason: '明文 password 泄漏到持久化 JSON',
      );
      expect(
        encrypted.containsKey('totpSecret'),
        isFalse,
        reason: '明文 totpSecret 泄漏到持久化 JSON',
      );
      expect(
        encrypted.containsKey('notes'),
        isFalse,
        reason: '明文 notes 泄漏到持久化 JSON',
      );
      expect(encrypted.containsKey('username'), isFalse);
      expect(encrypted.containsKey('email'), isFalse);

      // 密文字段必须存在
      expect(encrypted.containsKey('passwordEncrypted'), isTrue);
      expect(encrypted.containsKey('totpSecretEncrypted'), isTrue);
    });

    test('解密后能恢复原始明文（完整持久化往返）', () {
      final entry = LoginEntry(
        id: 'test-id',
        title: '测试登录',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        password: 'SuperSecret123!',
        totpSecret: 'JBSWY3DPEHPK3PXP',
      );

      final strategy = const LoginEncryptionStrategy();

      // 模拟真实持久化路径：加密 → 保存 JSON → 读取 JSON → 解密
      final persistedJson = strategy.encryptFields(entry, key);
      final decryptedJson = Map<String, dynamic>.from(persistedJson);
      strategy.decryptFields(decryptedJson, key);
      final decrypted = LoginEntry.fromJson(decryptedJson);

      expect(decrypted.password, equals('SuperSecret123!'));
      expect(decrypted.totpSecret, equals('JBSWY3DPEHPK3PXP'));
    });

    test('银行卡加密后 JSON 不得包含明文卡号与 CVV', () {
      final entry = BankCardEntry(
        id: 'card-id',
        title: '测试银行卡',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        cardNumber: '6222 0000 1234 5678',
        cvv: '123',
      );

      final encrypted = const BankCardEncryptionStrategy().encryptFields(
        entry,
        key,
      );

      expect(
        encrypted.containsKey('cardNumber'),
        isFalse,
        reason: '明文卡号泄漏到持久化 JSON',
      );
      expect(
        encrypted.containsKey('cvv'),
        isFalse,
        reason: '明文 CVV 泄漏到持久化 JSON',
      );
      expect(encrypted.containsKey('cardNumberEncrypted'), isTrue);
      expect(encrypted.containsKey('cvvEncrypted'), isTrue);
    });

    test('银行卡完整往返后恢复原始卡号', () {
      final entry = BankCardEntry(
        id: 'card-id',
        title: '测试银行卡',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        cardNumber: '6222 0000 1234 5678',
        cvv: '123',
      );

      final strategy = const BankCardEncryptionStrategy();
      final persistedJson = strategy.encryptFields(entry, key);
      final decryptedJson = Map<String, dynamic>.from(persistedJson);
      strategy.decryptFields(decryptedJson, key);
      final decrypted = BankCardEntry.fromJson(decryptedJson);

      expect(decrypted.cardNumber, equals('6222 0000 1234 5678'));
      expect(decrypted.cvv, equals('123'));
    });

    test('错误密钥解密应抛出异常', () {
      final entry = LoginEntry(
        id: 'test-id',
        title: '测试登录',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        password: 'SuperSecret123!',
      );

      final strategy = const LoginEncryptionStrategy();
      final persistedJson = strategy.encryptFields(entry, key);
      final wrongKey = CryptoService.generateKey();

      expect(
        () => strategy.decryptFields(persistedJson, wrongKey),
        throwsA(isA<Exception>()),
      );
    });

    test('旧格式（明文与密文并存）数据解密时以密文为准', () {
      // 兼容历史数据：修复前的版本会同时写入明文与密文字段
      final entry = LoginEntry(
        id: 'test-id',
        title: '测试登录',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        password: 'SuperSecret123!',
      );

      final strategy = const LoginEncryptionStrategy();
      final persistedJson = strategy.encryptFields(entry, key);

      // 模拟旧格式污染：把一条过期的明文字段塞回去
      persistedJson['password'] = 'PlainTextLeftOver!';

      strategy.decryptFields(persistedJson, key);
      final decrypted = LoginEntry.fromJson(persistedJson);

      // 解密结果应以密文解出的值为准
      expect(decrypted.password, equals('SuperSecret123!'));
    });
  });
}
