import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';

class CryptoService {
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM
  static const int _saltLength = 32; // 256 bits

  static const int _argon2MemoryPowerOf2 = 16; // 2^16 = 65536 KB = 64MB
  static const int _argon2Iterations = 3;
  static const int _argon2Parallelism = 4;
  static const int _argon2HashLength = 32; // 256 bits

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

  @Deprecated('使用 deriveKeyWithArgon2id 替代')
  static String hashPassword(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final digest = sha256.convert(salted);
    return digest.toString();
  }

  @Deprecated('使用 deriveKeyWithArgon2id 替代')
  static Uint8List deriveKey(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final digest = sha256.convert(salted);
    return Uint8List.fromList(digest.bytes);
  }

  static Uint8List deriveKeyWithArgon2id(
    String password,
    Uint8List salt,
  ) {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: _argon2HashLength,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: _argon2Iterations,
      memoryPowerOf2: _argon2MemoryPowerOf2,
      lanes: _argon2Parallelism,
    );

    final argon2 = Argon2BytesGenerator();
    argon2.init(parameters);

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final result = argon2.process(passwordBytes);

    return result;
  }

  static KeyMaterial deriveKeyMaterial(
    String password,
    Uint8List salt,
  ) {
    final key = deriveKeyWithArgon2id(password, salt);

    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    final hash = sha256.convert(salted).toString();

    return KeyMaterial(
      key: key,
      salt: salt,
      hash: hash,
      algorithm: 'argon2id',
      version: 2,
    );
  }

  static KeyMaterial generateKeyMaterial(String password) {
    final salt = generateSalt();
    return deriveKeyMaterial(password, salt);
  }

  static String calculateChecksum(List<Map<String, dynamic>> entries) {
    final jsonList = entries.map((e) => jsonEncode(e)).toList()..sort();
    final combined = jsonList.join();
    return sha256.convert(utf8.encode(combined)).toString();
  }

  static void secureClear(Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }

  static Map<String, dynamic> getArgon2Params() {
    return {
      'algorithm': 'Argon2id',
      'version': '1.3',
      'memoryPowerOf2': _argon2MemoryPowerOf2,
      'memoryKB': 1 << _argon2MemoryPowerOf2,
      'iterations': _argon2Iterations,
      'parallelism': _argon2Parallelism,
      'hashLength': _argon2HashLength,
    };
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

class KeyMaterial {
  final Uint8List key;
  final Uint8List salt;
  final String hash;
  final String algorithm;
  final int version;

  KeyMaterial({
    required this.key,
    required this.salt,
    required this.hash,
    this.algorithm = 'sha256',
    this.version = 1,
  });

  String get keyBase64 => base64Encode(key);

  String get saltBase64 => base64Encode(salt);

  Map<String, dynamic> toJson() => {
    'saltBase64': saltBase64,
    'hash': hash,
    'algorithm': algorithm,
    'version': version,
  };
}
