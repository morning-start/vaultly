import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';

class CryptoService {
  static const int _keyLength = 32;
  static const int _ivLength = 12;
  static const int _saltLength = 32;

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List generateSalt() => _generateRandomBytes(_saltLength);

  static Uint8List generateIV() => _generateRandomBytes(_ivLength);

  static Uint8List generateKey() => _generateRandomBytes(_keyLength);

  static String generateSaltBase64() {
    return base64Encode(generateSalt());
  }

  static String generateIVBase64() {
    return base64Encode(generateIV());
  }

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

  static String hashPassword(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final digest = sha256.convert(salted);
    return digest.toString();
  }

  static Uint8List deriveKey(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final digest = sha256.convert(salted);
    return Uint8List.fromList(digest.bytes);
  }

  static String calculateChecksum(List<Map<String, dynamic>> entries) {
    final jsonList = entries.map((e) => jsonEncode(e)).toList()..sort();
    final combined = jsonList.join();
    return sha256.convert(utf8.encode(combined)).toString();
  }
}

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
