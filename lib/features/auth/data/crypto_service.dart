import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';
import '../../../core/exceptions/app_exception.dart';

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

    try {
      return encrypter.decrypt(encrypted, iv: encrypt_lib.IV(iv));
    } catch (e) {
      // GCM 认证标签校验失败（密钥不匹配）或密文损坏时，pointycastle 抛出的
      // InvalidCipherTextException 没有 toString，直接上抛会变成
      // "Instance of 'InvalidCipherTextException'" 泄漏到 UI。
      // 这里统一映射为业务异常，保留原始错误便于诊断。
      throw CryptoException.decryptionFailed(e);
    }
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

  /// 按当前默认强度，配合给定盐值构造一套 KDF 参数
  static KdfParams defaultKdfParams(Uint8List salt) {
    return KdfParams(
      salt: salt,
      memoryPowerOf2: _argon2MemoryPowerOf2,
      iterations: _argon2Iterations,
      parallelism: _argon2Parallelism,
      keyLength: _argon2HashLength,
    );
  }

  static Uint8List deriveKeyWithArgon2id(
    String password,
    Uint8List salt,
  ) {
    return deriveKeyWithKdfParams(password, defaultKdfParams(salt));
  }

  /// 用「显式给定的」KDF 参数派生密钥。
  ///
  /// 与 [deriveKeyWithArgon2id] 的区别：这里的强度参数来自调用方
  /// （读取备份文件时来自文件头），而不是编译期常量。这样即使以后
  /// 调高 Argon2 内存/迭代强度，旧备份依然能用旧参数解开。
  static Uint8List deriveKeyWithKdfParams(
    String password,
    KdfParams params,
  ) {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      params.salt,
      desiredKeyLength: params.keyLength,
      version: params.argon2Version,
      iterations: params.iterations,
      memoryPowerOf2: params.memoryPowerOf2,
      lanes: params.parallelism,
    );

    final argon2 = Argon2BytesGenerator();
    argon2.init(parameters);

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final result = argon2.process(passwordBytes);

    return result;
  }

  /// 加密为「自描述信封」：把 KDF 参数和密文放在同一份文件里。
  ///
  /// 盐值不是秘密，它必须随密文一起走，否则换设备后同一个主密码
  /// 派生不出同一把密钥（详见 [KdfParams] 注释）。
  static EncryptedEnvelope encryptToEnvelope(
    String plainText,
    Uint8List key,
    KdfParams kdf,
  ) {
    return EncryptedEnvelope(
      kdf: kdf,
      data: encrypt(plainText, key),
    );
  }

  /// 解开自描述信封
  static String decryptEnvelope(EncryptedEnvelope envelope, Uint8List key) {
    return decrypt(envelope.data, key);
  }

  /// 口令校验哈希：sha256(主密码 ‖ 盐)
  ///
  /// 只用于本机判断「输入的主密码对不对」，不参与数据加密。
  static String deriveVerificationHash(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final salted = Uint8List.fromList([...bytes, ...salt]);
    return sha256.convert(salted).toString();
  }

  static KeyMaterial deriveKeyMaterial(
    String password,
    Uint8List salt,
  ) {
    final key = deriveKeyWithArgon2id(password, salt);

    return KeyMaterial(
      key: key,
      salt: salt,
      hash: deriveVerificationHash(password, salt),
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

  factory EncryptedData.fromJson(Map<String, dynamic> json) {
    final cipherText = json['cipherText'];
    final iv = json['iv'];
    final authTag = json['authTag'];

    if (cipherText is! String || iv is! String || authTag is! String) {
      throw const FormatException('EncryptedData 字段缺失或类型错误');
    }

    return EncryptedData(
      cipherText: cipherText,
      iv: iv,
      authTag: authTag,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Argon2id 密钥派生参数
///
/// 这些参数**不是秘密**，必须和密文放在一起保存。
///
/// 历史缺陷：盐值只用 `Random.secure()` 生成后写进本机安全存储
/// (`master_salt`)，备份文件里一个字节都不带。于是密钥实际上是
/// `Argon2id(主密码, 本机盐)` 而不是 `Argon2id(主密码)`——换手机后
/// 重新生成盐，同一个主密码派生出的密钥完全不同，云端备份必然解不开
/// （表现为 AES-GCM 认证标签校验失败）。
class KdfParams {
  /// 算法标识，便于以后平滑换成别的 KDF
  static const String algorithmArgon2id = 'argon2id';

  /// Argon2 版本 1.3 = 0x13
  static const int argon2Version13 = 19;

  /// 读取外部文件时允许的最大内存强度（2^24 KiB = 16 GiB 上限）。
  /// 防止被篡改的文件头声明一个天文数字的内存开销拖垮设备。
  static const int maxMemoryPowerOf2 = 24;

  final String algorithm;
  final Uint8List salt;

  /// Argon2 内存开销，以 2 的幂表示（16 = 64 MiB）
  final int memoryPowerOf2;
  final int iterations;
  final int parallelism;
  final int keyLength;
  final int argon2Version;

  KdfParams({
    required this.salt,
    required this.memoryPowerOf2,
    required this.iterations,
    required this.parallelism,
    required this.keyLength,
    this.algorithm = algorithmArgon2id,
    this.argon2Version = argon2Version13,
  });

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'salt': base64Encode(salt),
        'memoryPowerOf2': memoryPowerOf2,
        'iterations': iterations,
        'parallelism': parallelism,
        'keyLength': keyLength,
        'argon2Version': argon2Version,
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    final algorithm = json['algorithm'];
    final salt = json['salt'];
    final memoryPowerOf2 = json['memoryPowerOf2'];
    final iterations = json['iterations'];
    final parallelism = json['parallelism'];
    final keyLength = json['keyLength'];

    if (algorithm is! String ||
        salt is! String ||
        memoryPowerOf2 is! num ||
        iterations is! num ||
        parallelism is! num ||
        keyLength is! num) {
      throw const FormatException('备份文件的 KDF 参数缺失或类型错误');
    }

    if (memoryPowerOf2 < 1 || memoryPowerOf2 > maxMemoryPowerOf2) {
      throw FormatException('备份文件的 KDF 内存参数超出合理范围: $memoryPowerOf2');
    }
    if (iterations < 1 || parallelism < 1 || keyLength < 16) {
      throw const FormatException('备份文件的 KDF 参数不合法');
    }

    final saltBytes = base64Decode(salt);
    if (saltBytes.length < 16) {
      throw const FormatException('备份文件的盐值长度不足');
    }

    return KdfParams(
      algorithm: algorithm,
      salt: saltBytes,
      memoryPowerOf2: memoryPowerOf2.toInt(),
      iterations: iterations.toInt(),
      parallelism: parallelism.toInt(),
      keyLength: keyLength.toInt(),
      argon2Version: (json['argon2Version'] as num?)?.toInt() ?? argon2Version13,
    );
  }

  /// 与另一套参数是否等价（用于判断备份是否来自同一套密钥体系）
  bool matches(KdfParams other) =>
      algorithm == other.algorithm &&
      memoryPowerOf2 == other.memoryPowerOf2 &&
      iterations == other.iterations &&
      parallelism == other.parallelism &&
      keyLength == other.keyLength &&
      argon2Version == other.argon2Version &&
      _bytesEqual(salt, other.salt);
}

/// 定长字节比较（避免为一个比较引入额外依赖）
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 自描述加密信封（备份文件格式 v2）
///
/// 与只装密文的 [EncryptedData] 不同，信封把「解它需要哪套 KDF 参数」
/// 也写在文件里，因此任何设备只要输入正确的主密码就能解开，
/// 不再依赖原设备残留的本机数据。
///
/// 文件头本身被隐式认证：盐值/强度参数被篡改 → 派生出的密钥不同 →
/// GCM 认证标签校验必然失败，不会解出错误数据。
class EncryptedEnvelope {
  /// 当前信封格式版本（1 = 旧的无盐纯密文格式）
  static const int currentVersion = 2;

  static const String formatTag = 'vaultly-backup';
  static const String cipherAesGcm = 'AES-256-GCM';

  final int version;
  final String format;
  final String cipher;
  final KdfParams kdf;
  final EncryptedData data;

  EncryptedEnvelope({
    required this.kdf,
    required this.data,
    this.version = currentVersion,
    this.format = formatTag,
    this.cipher = cipherAesGcm,
  });

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'cipher': cipher,
        'kdf': kdf.toJson(),
        'data': data.toJson(),
      };

  /// 判断解析出的 JSON 是否为信封格式（旧格式只有 cipherText/iv/authTag）
  static bool isEnvelope(Map<String, dynamic> json) =>
      json['kdf'] is Map && json['data'] is Map;

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) {
    final kdf = json['kdf'];
    final data = json['data'];
    if (kdf is! Map || data is! Map) {
      throw const FormatException('备份文件不是有效的加密信封');
    }

    return EncryptedEnvelope(
      kdf: KdfParams.fromJson(Map<String, dynamic>.from(kdf)),
      data: EncryptedData.fromJson(Map<String, dynamic>.from(data)),
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
      format: json['format'] as String? ?? formatTag,
      cipher: json['cipher'] as String? ?? cipherAesGcm,
    );
  }
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
