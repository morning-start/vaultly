import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/auth/data/crypto_service.dart';

/// HKDF-SHA256（RFC 5869）正确性测试
///
/// 这是 R1 的安全基石：口令校验值与密钥体系指纹都由它派生，
/// 实现错了会静默降级为「看起来能跑但不等价」的派生。
/// 任何自实现都必须先过官方测试向量。
void main() {
  String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  Uint8List repeat(int value, int count) =>
      Uint8List.fromList(List.filled(count, value));

  group('RFC 5869 官方测试向量（SHA-256）', () {
    test('Test Case 1：带 salt 与 info，输出 42 字节', () {
      final okm = CryptoService.hkdfSha256Bytes(
        ikm: repeat(0x0b, 22),
        salt: bytes(List.generate(13, (i) => i)),
        info: List.generate(10, (i) => 0xf0 + i),
        length: 42,
      );

      expect(
        hex(okm),
        equals(
          '3cb25f25faacd57a90434f64d0362f2a'
          '2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
          '34007208d5b887185865',
        ),
      );
    });

    test('Test Case 3：salt 与 info 均为空，输出 42 字节', () {
      final okm = CryptoService.hkdfSha256Bytes(
        ikm: repeat(0x0b, 22),
        salt: Uint8List(0),
        info: const <int>[],
        length: 42,
      );

      expect(
        hex(okm),
        equals(
          '8da4e775a563c18f715f802a063c5a31'
          'b8a11f5c5ee1879ec3454e5f3c738d2d'
          '9d201395faa4b61a96c8',
        ),
      );
    });
  });

  group('域分离', () {
    test('同一 masterSecret 的三种用途应派生出互不相同的值', () {
      final masterSecret = repeat(0x42, 32);

      final auth = CryptoService.deriveAuthKey(masterSecret);
      final kek = CryptoService.deriveWrapKey(masterSecret);
      final tag = CryptoService.deriveKeyTag(masterSecret);

      expect(hex(auth), isNot(equals(hex(kek))));
      expect(hex(kek), isNot(equals(tag)));
      expect(hex(auth), isNot(equals(tag)));
      expect(auth.length, equals(32));
      expect(kek.length, equals(32));
    });

    test('派生应可复现（同一输入 → 同一输出）', () {
      final masterSecret = repeat(0x7f, 32);

      expect(
        CryptoService.deriveKeyTag(masterSecret),
        equals(CryptoService.deriveKeyTag(masterSecret)),
      );
      expect(
        CryptoService.deriveAuthKey(masterSecret),
        equals(CryptoService.deriveAuthKey(masterSecret)),
      );
    });

    test('不同 masterSecret（改密/换盐）应得到不同指纹', () {
      expect(
        CryptoService.deriveKeyTag(repeat(0x01, 32)),
        isNot(equals(CryptoService.deriveKeyTag(repeat(0x02, 32)))),
      );
    });

    test('校验值与加密密钥不可互相推导（域分离的意义）', () {
      final masterSecret = repeat(0x11, 32);
      final auth = CryptoService.deriveAuthKey(masterSecret);

      // authKey 与 masterSecret 本身必须不同，否则落盘校验值等于泄漏密钥
      expect(hex(auth), isNot(equals(hex(masterSecret))));
    });
  });

  group('constantTimeEquals', () {
    test('相同内容返回 true，不同内容返回 false', () {
      expect(CryptoService.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(CryptoService.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    });

    test('长度不同返回 false', () {
      expect(CryptoService.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
      expect(CryptoService.constantTimeEquals([], [1]), isFalse);
    });
  });
}
