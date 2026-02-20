import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';

/// 加密服务
/// 
/// 参考文档: wiki/02-架构设计/安全架构.md
/// 使用 AES-256-GCM 加密算法
/// 使用 SHA-256 进行密钥派生
class CryptoService {
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM
  static const int _saltLength = 32; // 256 bits

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// 生成随机盐值
  static Uint8List generateSalt() => _generateRandomBytes(_saltLength);

  /// 生成随机 IV
  static Uint8List generateIV() => _generateRandomBytes(_ivLength);

  /// 生成随机密钥
  static Uint8List generateKey() => _generateRandomBytes(_keyLength);

  /// 生成 Base64 编码的盐值
  static String generateSaltBase64() {
    return base64Encode(generateSalt());
  }

  /// 生成 Base64 编码的 IV
  static String generateIVBase64() {
    return base64Encode(generateIV());
  }

  /// 使用 AES-256-GCM 加密数据
  /// 
  /// 返回加密数据，包含密文、IV 和认证标签
  static EncryptedData encrypt(String plainText, Uint8List key) {
    final iv = generateIV();
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(encrypt_lib.Key(key), mode: encrypt_lib.AESMode.gcm),
    );
    final encrypted = encrypter.encrypt(plainText, iv: encrypt_lib.IV(iv));

    final cipherText = encrypted.bytes;
    final authTag = cipherText.sublist(cipherText.length - 16);
    final cipher = cipherText.sublist(0, cipherText.length - 16);

    return EncryptedData(
      cipherText: base64Encode(cipher),
      iv: base64Encode(iv),
      authTag: base64Encode(authTag),
      version: 1,
    );
  }

  /// 使用 AES-256-GCM 解密数据
  static String decrypt(EncryptedData encryptedData, Uint8List key) {
    final iv = base64Decode(encryptedData.iv);
    final cipher = base64Decode(encryptedData.cipherText);
    final authTag = base64Decode(encryptedData.authTag);

    final combined = Uint8List.fromList([...cipher, ...authTag]);
    final encrypted = encrypt_lib.Encrypted(combined);

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(encrypt_lib.Key(key), mode: encrypt_lib.AESMode.gcm),
    );

    return encrypter.decrypt(encrypted, iv: encrypt_lib.IV(iv));
  }

  /// 使用 SHA-256 哈希密码
  static String hashPassword(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final digest = sha256.convert(salted);
    return digest.toString();
  }

  /// 使用 SHA-256 派生密钥
  static Uint8List deriveKey(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final digest = sha256.convert(salted);
    return Uint8List.fromList(digest.bytes);
  }

  /// 使用 SHA-256 派生密钥材料（替代 Argon2id）
  ///
  /// 使用 hashPassword 生成哈希，确保注册和登录使用相同的哈希算法
  static Future<KeyMaterial> deriveKeyMaterial(
    String password,
    Uint8List salt,
  ) async {
    final key = deriveKey(password, salt);
    final hash = hashPassword(password, salt);

    return KeyMaterial(
      key: key,
      salt: salt,
      hash: hash,
    );
  }

  /// 生成新的密钥材料
  static Future<KeyMaterial> generateKeyMaterial(String password) async {
    final salt = generateSalt();
    return deriveKeyMaterial(password, salt);
  }

  /// 计算条目校验和
  static String calculateChecksum(List<Map<String, dynamic>> entries) {
    final jsonList = entries.map((e) => jsonEncode(e)).toList()..sort();
    final combined = jsonList.join();
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// 安全清除 Uint8List 内容
  /// 
  /// 将内存中的敏感数据覆写为零
  static void secureClear(Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }
}

/// 加密数据结构
class EncryptedData {
  final String cipherText;
  final String iv;
  final String authTag;
  final int version;

  EncryptedData({
    required this.cipherText,
    required this.iv,
    required this.authTag,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
    'cipherText': cipherText,
    'iv': iv,
    'authTag': authTag,
    'version': version,
  };

  factory EncryptedData.fromJson(Map<String, dynamic> json) => EncryptedData(
    cipherText: json['cipherText'],
    iv: json['iv'],
    authTag: json['authTag'],
    version: json['version'],
  );
}

/// 密钥材料
/// 
/// 包含派生密钥、盐值和哈希
class KeyMaterial {
  final Uint8List key;
  final Uint8List salt;
  final String hash;

  KeyMaterial({
    required this.key,
    required this.salt,
    required this.hash,
  });

  /// 获取 Base64 编码的密钥
  String get keyBase64 => base64Encode(key);

  /// 获取 Base64 编码的盐值
  String get saltBase64 => base64Encode(salt);
}
