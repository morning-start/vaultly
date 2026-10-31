import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vaultly_core/vaultly_core.dart';

/// 备份信封（跨设备恢复）回归测试
///
/// 背景缺陷：AES 密钥 = Argon2id(主密码, 盐)，而盐值只在原设备的安全存储里，
/// 备份文件不带盐。换新手机后同一个主密码派生出的密钥不同，云端备份必然
/// 解不开（AES-GCM 认证标签校验失败）。
///
/// 修复：备份改为「自描述信封」——KDF 参数（含盐值）与密文写在同一个文件里，
/// 任何设备用主密码 + 文件里的盐值就能派生出一致的密钥。
void main() {
  /// 低强度参数：参数由文件头显式给出，测试里不需要 64MB 的开销
  KdfParams lightParams(Uint8List salt) => KdfParams(
    salt: salt,
    memoryPowerOf2: 10,
    iterations: 1,
    parallelism: 1,
    keyLength: 32,
  );

  const password = 'correct horse battery staple';
  const payload = '{"version":1,"entries":[{"type":"login","title":"GitHub"}]}';

  group('KdfParams', () {
    test('JSON 往返应保留盐值与强度参数', () {
      final params = lightParams(CryptoService.generateSalt());
      final restored = KdfParams.fromJson(
        jsonDecode(jsonEncode(params.toJson())) as Map<String, dynamic>,
      );

      expect(restored.matches(params), isTrue);
      expect(restored.salt, equals(params.salt));
      expect(restored.memoryPowerOf2, equals(params.memoryPowerOf2));
    });

    test('盐值不同的参数不应视为同一套', () {
      final a = lightParams(CryptoService.generateSalt());
      final b = lightParams(CryptoService.generateSalt());
      expect(a.matches(b), isFalse);
    });

    test('内存强度超限应拒绝（防篡改文件头拖垮设备）', () {
      final params = lightParams(CryptoService.generateSalt()).toJson();
      params['memoryPowerOf2'] = 40;

      expect(() => KdfParams.fromJson(params), throwsA(isA<FormatException>()));
    });

    test('盐值过短应拒绝', () {
      final params = lightParams(CryptoService.generateSalt()).toJson();
      params['salt'] = base64Encode(Uint8List(8));

      expect(() => KdfParams.fromJson(params), throwsA(isA<FormatException>()));
    });

    test('字段缺失应拒绝', () {
      expect(
        () => KdfParams.fromJson({'algorithm': 'argon2id'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('EncryptedEnvelope', () {
    test('信封应能被识别，旧格式不应被误判为信封', () {
      final kdf = lightParams(CryptoService.generateSalt());
      final key = CryptoService.deriveKeyWithKdfParams(password, kdf);
      final envelope = CryptoService.encryptToEnvelope(payload, key, kdf);

      expect(EncryptedEnvelope.isEnvelope(envelope.toJson()), isTrue);
      // 旧格式：只有 cipherText / iv / authTag
      expect(
        EncryptedEnvelope.isEnvelope({
          'cipherText': 'x',
          'iv': 'y',
          'authTag': 'z',
          'version': 1,
        }),
        isFalse,
      );
    });

    test('信封内的密文应能解回原文', () {
      final kdf = lightParams(CryptoService.generateSalt());
      final key = CryptoService.deriveKeyWithKdfParams(password, kdf);
      final envelope = CryptoService.encryptToEnvelope(payload, key, kdf);

      final decoded = EncryptedEnvelope.fromJson(
        jsonDecode(jsonEncode(envelope.toJson())) as Map<String, dynamic>,
      );

      expect(CryptoService.decryptEnvelope(decoded, key), equals(payload));
    });

    test('仅凭「主密码 + 文件头」应能解开——换设备场景', () {
      // 设备 A：本机盐值 A，上传备份
      final kdfA = lightParams(CryptoService.generateSalt());
      final keyA = CryptoService.deriveKeyWithKdfParams(password, kdfA);
      final uploaded = jsonEncode(
        CryptoService.encryptToEnvelope(payload, keyA, kdfA).toJson(),
      );

      // 设备 B：本机盐值完全不同（新手机设同一个主密码时随机生成）
      final kdfB = lightParams(CryptoService.generateSalt());
      expect(kdfA.matches(kdfB), isFalse, reason: '两台设备的盐值本来就应该不同');

      // 设备 B 用旧做法（只用本机盐派生）必然失败——这就是原始 bug
      final keyB = CryptoService.deriveKeyWithKdfParams(password, kdfB);
      expect(keyB, isNot(equals(keyA)));

      // 修复后的做法：解析文件头，用文件里的参数派生
      final envelope = EncryptedEnvelope.fromJson(
        jsonDecode(uploaded) as Map<String, dynamic>,
      );
      final recoveredKey = CryptoService.deriveKeyWithKdfParams(
        password,
        envelope.kdf,
      );

      expect(
        recoveredKey,
        equals(keyA),
        reason: '同一个主密码 + 同一套 KDF 参数必须派生出同一把密钥',
      );
      expect(
        CryptoService.decryptEnvelope(envelope, recoveredKey),
        equals(payload),
      );
    });

    test('主密码错误应抛出 CryptoException 而不是裸露的底层异常', () {
      final kdf = lightParams(CryptoService.generateSalt());
      final key = CryptoService.deriveKeyWithKdfParams(password, kdf);
      final envelope = CryptoService.encryptToEnvelope(payload, key, kdf);

      final wrongKey = CryptoService.deriveKeyWithKdfParams(
        'wrong password',
        kdf,
      );

      expect(
        () => CryptoService.decryptEnvelope(envelope, wrongKey),
        throwsA(isA<CryptoException>()),
      );
    });

    test('文件头盐值被篡改应导致解密失败（头部被隐式认证）', () {
      final kdf = lightParams(CryptoService.generateSalt());
      final key = CryptoService.deriveKeyWithKdfParams(password, kdf);
      final json = CryptoService.encryptToEnvelope(payload, key, kdf).toJson();

      // 攻击者替换盐值，密文保持不变
      final tampered = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      final tamperedKdf = Map<String, dynamic>.from(
        tampered['kdf'] as Map<String, dynamic>,
      );
      tamperedKdf['salt'] = base64Encode(CryptoService.generateSalt());
      tampered['kdf'] = tamperedKdf;

      final envelope = EncryptedEnvelope.fromJson(tampered);
      final derivedFromTampered = CryptoService.deriveKeyWithKdfParams(
        password,
        envelope.kdf,
      );

      expect(
        () => CryptoService.decryptEnvelope(envelope, derivedFromTampered),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}
