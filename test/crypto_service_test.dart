import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/auth/data/crypto_service.dart';

void main() {
  group('CryptoService', () {
    group('密钥生成', () {
      test('generateSalt 应返回 32 字节随机盐值', () {
        final salt = CryptoService.generateSalt();
        expect(salt.length, equals(32));
      });

      test('generateIV 应返回 12 字节随机 IV', () {
        final iv = CryptoService.generateIV();
        expect(iv.length, equals(12));
      });

      test('generateKey 应返回 32 字节随机密钥', () {
        final key = CryptoService.generateKey();
        expect(key.length, equals(32));
      });

      test('多次生成的盐值应不同', () {
        final salt1 = CryptoService.generateSalt();
        final salt2 = CryptoService.generateSalt();
        expect(salt1, isNot(equals(salt2)));
      });
    });

    group('AES-256-GCM 加密', () {
      late Uint8List key;

      setUp(() {
        key = CryptoService.generateKey();
      });

      test('加密应返回 EncryptedData 对象', () {
        const plainText = 'Hello, World!';
        final encrypted = CryptoService.encrypt(plainText, key);

        expect(encrypted, isA<EncryptedData>());
        expect(encrypted.cipherText, isNotEmpty);
        expect(encrypted.iv, isNotEmpty);
        expect(encrypted.authTag, isNotEmpty);
        expect(encrypted.version, equals(1));
      });

      test('解密应返回原始明文', () {
        const plainText = 'Hello, World!';
        final encrypted = CryptoService.encrypt(plainText, key);
        final decrypted = CryptoService.decrypt(encrypted, key);

        expect(decrypted, equals(plainText));
      });

      test('不同密钥解密应失败', () {
        const plainText = 'Hello, World!';
        final encrypted = CryptoService.encrypt(plainText, key);
        final wrongKey = CryptoService.generateKey();

        expect(
          () => CryptoService.decrypt(encrypted, wrongKey),
          throwsException,
        );
      });

      test('加密长文本应正常工作', () {
        final plainText =
            'This is a very long text that should be encrypted and decrypted correctly. ' *
            100;
        final encrypted = CryptoService.encrypt(plainText, key);
        final decrypted = CryptoService.decrypt(encrypted, key);

        expect(decrypted, equals(plainText));
      });

      test('加密 Unicode 文本应正常工作', () {
        const plainText = '你好，世界！🌍 ñáéíóú';
        final encrypted = CryptoService.encrypt(plainText, key);
        final decrypted = CryptoService.decrypt(encrypted, key);

        expect(decrypted, equals(plainText));
      });

      test('空字符串加密解密应正常工作', () {
        const plainText = '';
        final encrypted = CryptoService.encrypt(plainText, key);
        final decrypted = CryptoService.decrypt(encrypted, key);

        expect(decrypted, equals(plainText));
      });
    });

    group('Argon2id 密钥派生', () {
      test('deriveKeyWithArgon2id 应返回 32 字节密钥', () {
        const password = 'test_password';
        final salt = CryptoService.generateSalt();

        final key = CryptoService.deriveKeyWithArgon2id(password, salt);

        expect(key.length, equals(32));
      });

      test('相同密码和盐值应派生相同密钥', () {
        const password = 'test_password';
        final salt = CryptoService.generateSalt();

        final key1 = CryptoService.deriveKeyWithArgon2id(password, salt);
        final key2 = CryptoService.deriveKeyWithArgon2id(password, salt);

        expect(key1, equals(key2));
      });

      test('不同密码应派生不同密钥', () {
        const password1 = 'password1';
        const password2 = 'password2';
        final salt = CryptoService.generateSalt();

        final key1 = CryptoService.deriveKeyWithArgon2id(password1, salt);
        final key2 = CryptoService.deriveKeyWithArgon2id(password2, salt);

        expect(key1, isNot(equals(key2)));
      });

      test('不同盐值应派生不同密钥', () {
        const password = 'test_password';
        final salt1 = CryptoService.generateSalt();
        final salt2 = CryptoService.generateSalt();

        final key1 = CryptoService.deriveKeyWithArgon2id(password, salt1);
        final key2 = CryptoService.deriveKeyWithArgon2id(password, salt2);

        expect(key1, isNot(equals(key2)));
      });
    });

    group('密钥材料', () {
      test('generateKeyMaterial 应返回 KeyMaterial', () {
        const password = 'test_password';

        final keyMaterial = CryptoService.generateKeyMaterial(password);

        expect(keyMaterial, isA<KeyMaterial>());
        expect(keyMaterial.key.length, equals(32));
        expect(keyMaterial.salt.length, equals(32));
        expect(keyMaterial.hash, isNotEmpty);
        expect(keyMaterial.algorithm, equals('argon2id'));
        expect(keyMaterial.version, equals(2));
      });

      test('deriveKeyMaterial 应使用提供的盐值', () {
        const password = 'test_password';
        final salt = CryptoService.generateSalt();

        final keyMaterial = CryptoService.deriveKeyMaterial(password, salt);

        expect(keyMaterial.salt, equals(salt));
      });

      test('KeyMaterial.toJson 应返回正确的 JSON', () {
        const password = 'test_password';

        final keyMaterial = CryptoService.generateKeyMaterial(password);
        final json = keyMaterial.toJson();

        expect(json['saltBase64'], equals(base64Encode(keyMaterial.salt)));
        expect(json['hash'], equals(keyMaterial.hash));
        expect(json['algorithm'], equals('argon2id'));
        expect(json['version'], equals(2));
      });
    });

    group('安全清除', () {
      test('secureClear 应将数据清零', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);

        CryptoService.secureClear(data);

        expect(data, equals(Uint8List.fromList([0, 0, 0, 0, 0])));
      });
    });

    group('Argon2 参数', () {
      test('getArgon2Params 应返回正确的参数', () {
        final params = CryptoService.getArgon2Params();

        expect(params['algorithm'], equals('Argon2id'));
        expect(params['version'], equals('1.3'));
        expect(params['memoryPowerOf2'], equals(16));
        expect(params['memoryKB'], equals(65536));
        expect(params['iterations'], equals(3));
        expect(params['parallelism'], equals(4));
        expect(params['hashLength'], equals(32));
      });
    });

    group('校验和', () {
      test('calculateChecksum 应返回 SHA-256 哈希', () {
        final entries = [
          {'id': '1', 'title': 'Entry 1'},
          {'id': '2', 'title': 'Entry 2'},
        ];

        final checksum = CryptoService.calculateChecksum(entries);

        expect(checksum.length, equals(64)); // SHA-256 十六进制字符串长度
      });

      test('相同条目应产生相同校验和', () {
        final entries = [
          {'id': '1', 'title': 'Entry 1'},
          {'id': '2', 'title': 'Entry 2'},
        ];

        final checksum1 = CryptoService.calculateChecksum(entries);
        final checksum2 = CryptoService.calculateChecksum(entries);

        expect(checksum1, equals(checksum2));
      });

      test('不同条目应产生不同校验和', () {
        final entries1 = [
          {'id': '1', 'title': 'Entry 1'},
        ];
        final entries2 = [
          {'id': '1', 'title': 'Entry 2'},
        ];

        final checksum1 = CryptoService.calculateChecksum(entries1);
        final checksum2 = CryptoService.calculateChecksum(entries2);

        expect(checksum1, isNot(equals(checksum2)));
      });
    });

    group('EncryptedData', () {
      test('toJson 和 fromJson 应正确序列化', () {
        final data = EncryptedData(
          cipherText: 'cipher',
          iv: 'iv',
          authTag: 'tag',
          version: 1,
        );

        final json = data.toJson();
        final restored = EncryptedData.fromJson(json);

        expect(restored.cipherText, equals(data.cipherText));
        expect(restored.iv, equals(data.iv));
        expect(restored.authTag, equals(data.authTag));
        expect(restored.version, equals(data.version));
      });
    });
  });
}
