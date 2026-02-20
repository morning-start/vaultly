import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/crypto/services/crypto_service.dart';

void main() {
  group('AuthService 密码验证测试', () {
    test('注册和登录应该使用相同的哈希算法', () async {
      const password = 'test_password_123';

      // 模拟注册过程
      final keyMaterial = CryptoService.generateKeyMaterial(password);
      final storedHash = keyMaterial.hash;
      final storedSalt = keyMaterial.salt;

      // 模拟登录过程 - 使用相同的密码和盐值派生密钥材料
      final computedKeyMaterial = CryptoService.deriveKeyMaterial(password, storedSalt);

      // 验证哈希值应该相同
      expect(computedKeyMaterial.hash, equals(storedHash),
          reason: '注册和登录生成的哈希值应该相同');
    });

    test('不同密码应该生成不同的哈希', () async {
      const password1 = 'password_one';
      const password2 = 'password_two';

      final keyMaterial1 = CryptoService.generateKeyMaterial(password1);
      final keyMaterial2 = CryptoService.generateKeyMaterial(password2);

      expect(keyMaterial1.hash, isNot(equals(keyMaterial2.hash)));
    });

    test('相同密码不同盐值应该生成不同的哈希', () async {
      const password = 'same_password';

      final keyMaterial1 = CryptoService.generateKeyMaterial(password);
      final keyMaterial2 = CryptoService.generateKeyMaterial(password);

      expect(keyMaterial1.hash, isNot(equals(keyMaterial2.hash)),
          reason: '不同盐值应该生成不同的哈希');
      expect(keyMaterial1.salt, isNot(equals(keyMaterial2.salt)),
          reason: '盐值应该不同');
    });

    test('密钥派生应该一致', () async {
      const password = 'test_password';

      final keyMaterial = CryptoService.generateKeyMaterial(password);
      final derivedKeyMaterial = CryptoService.deriveKeyMaterial(password, keyMaterial.salt);

      expect(derivedKeyMaterial.key, equals(keyMaterial.key),
          reason: '派生的密钥应该与密钥材料中的密钥相同');
    });

    test('Argon2id 密钥派生应该产生正确的密钥长度', () async {
      const password = 'test_password';
      final salt = CryptoService.generateSalt();

      final key = CryptoService.deriveKeyWithArgon2id(password, salt);

      expect(key.length, equals(32), reason: 'Argon2id 应该生成 256 位 (32 字节) 密钥');
    });

    test('Argon2id 参数应该符合安全标准', () {
      final params = CryptoService.getArgon2Params();

      expect(params['algorithm'], equals('Argon2id'));
      expect(params['version'], equals('1.3'));
      expect(params['memoryKB'], equals(65536), reason: '内存应该为 64MB');
      expect(params['iterations'], equals(3));
      expect(params['parallelism'], equals(4));
      expect(params['hashLength'], equals(32));
    });

    test('密钥材料应该包含正确的算法信息', () async {
      const password = 'test_password';

      final keyMaterial = CryptoService.generateKeyMaterial(password);

      expect(keyMaterial.algorithm, equals('argon2id'));
      expect(keyMaterial.version, equals(2));
      expect(keyMaterial.key.length, equals(32));
      expect(keyMaterial.salt.length, equals(32));
    });
  });
}
