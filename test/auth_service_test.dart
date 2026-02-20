import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/crypto/services/crypto_service.dart';

void main() {
  group('AuthService 密码验证测试', () {
    test('注册和登录应该使用相同的哈希算法', () async {
      const password = 'test_password_123';
      
      // 模拟注册过程
      final keyMaterial = await CryptoService.generateKeyMaterial(password);
      final storedHash = keyMaterial.hash;
      final storedSalt = keyMaterial.salt;
      
      // 模拟登录过程
      final computedHash = CryptoService.hashPassword(password, storedSalt);
      
      // 验证哈希值应该相同
      expect(computedHash, equals(storedHash),
          reason: '注册和登录生成的哈希值应该相同');
    });

    test('不同密码应该生成不同的哈希', () async {
      const password1 = 'password_one';
      const password2 = 'password_two';
      
      final keyMaterial1 = await CryptoService.generateKeyMaterial(password1);
      final keyMaterial2 = await CryptoService.generateKeyMaterial(password2);
      
      expect(keyMaterial1.hash, isNot(equals(keyMaterial2.hash)));
    });

    test('相同密码不同盐值应该生成不同的哈希', () async {
      const password = 'same_password';
      
      final keyMaterial1 = await CryptoService.generateKeyMaterial(password);
      final keyMaterial2 = await CryptoService.generateKeyMaterial(password);
      
      expect(keyMaterial1.hash, isNot(equals(keyMaterial2.hash)),
          reason: '不同盐值应该生成不同的哈希');
      expect(keyMaterial1.salt, isNot(equals(keyMaterial2.salt)),
          reason: '盐值应该不同');
    });

    test('密钥派生应该一致', () async {
      const password = 'test_password';
      
      final keyMaterial = await CryptoService.generateKeyMaterial(password);
      final derivedKey = CryptoService.deriveKey(password, keyMaterial.salt);
      
      expect(derivedKey, equals(keyMaterial.key),
          reason: '派生的密钥应该与密钥材料中的密钥相同');
    });
  });
}
