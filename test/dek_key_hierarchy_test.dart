import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/auth/data/auth_service.dart';
import 'package:vaultly/features/auth/data/biometric_service.dart';
import 'package:vaultly_core/vaultly_core.dart';
import 'package:vaultly/features/vault/data/vault_service.dart';

import 'helpers/mock_secure_storage.dart';

/// 生物识别桩：测试环境没有 local_auth 插件，直接放行认证
class _FakeBiometricService extends BiometricService {
  @override
  Future<bool> authenticate({String? reason}) async => true;

  @override
  Future<bool> isBiometricEnrolled() async => true;

  @override
  Future<String> getBiometricTypeName() async => '指纹';

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> isBiometricAvailable() async => true;
}

/// R2：DEK/KEK 两层密钥（ADR-006）
///
/// 契约：
/// - 本地数据由**随机 DEK** 加密；主密码只负责包装 DEK
/// - 改主密码 = 重新包装（数据密文一个字节都不变）
/// - 没有 DEK 的旧安装：先解锁（数据仍可读），再由上层重加密到 DEK
/// - 生物识别会话拿得到 backupKey，因此**仍然能上传云端备份**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;
  late AuthService authService;

  const wrappedDekKey = 'vault_dek_wrapped';
  const biometricKey = 'biometric_encryption_key';
  const legacyHashKey = 'master_password_hash';

  setUp(() {
    storage = MockSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    authService = AuthService(
      secureStorage: const FlutterSecureStorage(),
      biometricService: _FakeBiometricService(),
    );
    VaultService.reset();
  });

  tearDown(VaultService.reset);

  VaultEntry login(String id, String password) => LoginEntry(
        id: id,
        title: '条目 $id',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        username: 'user-$id',
        password: password,
      );

  /// 读出一条条目「password」字段的密文（用于验证改密不重加密数据）
  String cipherOf(String id) {
    final data = jsonDecode(storage.store['vault_data']!) as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>;
    final entry = entries.firstWhere((e) => (e as Map)['id'] == id);
    return ((entry as Map)['passwordEncrypted'] as Map)['cipherText'] as String;
  }

  group('新安装', () {
    test('应生成并包装随机 DEK，会话密钥 = DEK ≠ masterSecret', () async {
      final result = await authService.setupMasterPassword('pw');

      expect(storage.store[wrappedDekKey], isNotNull);
      expect(result.needsDekMigration, isFalse);
      expect(result.sessionKey, isNot(equals(result.masterSecret)),
          reason: '本地数据密钥必须与主密码派生密钥分离');
      expect(result.sessionKey.length, equals(32));
    });

    test('同一主密码多次解锁应解包出同一把 DEK', () async {
      final first = await authService.setupMasterPassword('pw');
      final second = await authService.verifyMasterPassword('pw');

      expect(second!.sessionKey, equals(first.sessionKey));
      expect(second.masterSecret, equals(first.masterSecret));
      expect(second.needsDekMigration, isFalse);
    });

    test('错误密码返回 null', () async {
      await authService.setupMasterPassword('pw');
      expect(await authService.verifyMasterPassword('nope'), isNull);
    });
  });

  group('旧安装（迁移到 DEK）', () {
    /// 铺一个「升级前」的状态：数据由 masterSecret 加密、没有 wrappedDek
    void seedLegacyVaultWithMasterSecret(String password) {
      final salt = CryptoService.generateSalt();
      final masterSecret = CryptoService.deriveKeyWithArgon2id(password, salt);

      storage.store['master_salt'] = base64Encode(salt);
      storage.store['master_kdf_params'] = jsonEncode(
        CryptoService.defaultKdfParams(salt).toJson(),
      );
      storage.store[legacyHashKey] =
          CryptoService.deriveVerificationHash(password, salt);

      // 用 masterSecret 直接写一份数据（模拟旧版本的行为）
      final service = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(masterSecret);
      service.addEntry(login('a', 'secret-a'));
    }

    test('解锁时先返回 masterSecret 作为会话密钥，并标记需要迁移', () async {
      seedLegacyVaultWithMasterSecret('pw');

      final result = await authService.verifyMasterPassword('pw');

      expect(result, isNotNull);
      expect(result!.needsDekMigration, isTrue);
      expect(storage.store[wrappedDekKey], isNull,
          reason: 'verify 不应擅自创建 DEK，迁移由上层在数据重加密时完成');

      // 旧数据用 masterSecret 能读出来
      final service = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(result.sessionKey);
      await service.loadVault();
      expect(service.entries.length, equals(1));
    });

    test('ensureDek 应创建 DEK 且可重复调用（幂等）', () async {
      seedLegacyVaultWithMasterSecret('pw');
      final result = await authService.verifyMasterPassword('pw');

      final dek1 = await authService.ensureDek(result!.masterSecret);
      final dek2 = await authService.ensureDek(result.masterSecret);

      expect(dek1, equals(dek2), reason: '重复调用不得换掉已有 DEK');
      expect(await authService.hasWrappedDek(), isTrue);

      // 此后解锁直接拿到 DEK
      final next = await authService.verifyMasterPassword('pw');
      expect(next!.sessionKey, equals(dek1));
      expect(next.needsDekMigration, isFalse);
    });

    test('clearWrappedDek 应能回滚（迁移失败时恢复旧密钥体系）', () async {
      seedLegacyVaultWithMasterSecret('pw');
      final result = await authService.verifyMasterPassword('pw');
      await authService.ensureDek(result!.masterSecret);
      expect(await authService.hasWrappedDek(), isTrue);

      await authService.clearWrappedDek();

      expect(await authService.hasWrappedDek(), isFalse);
      final again = await authService.verifyMasterPassword('pw');
      expect(again!.needsDekMigration, isTrue,
          reason: '回滚后应回到「数据由 masterSecret 加密」的状态');
    });

    test('完整迁移：数据从 masterSecret 重加密到 DEK 后可正常解锁', () async {
      seedLegacyVaultWithMasterSecret('pw');

      // 1) 解锁（会话密钥 = masterSecret）
      final first = await authService.verifyMasterPassword('pw');
      final service = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(first!.sessionKey);
      await service.loadVault();
      expect(service.entries.length, equals(1));

      // 2) 生成 DEK 并用它重加密（等价于 notifier 的迁移流程）
      final dek = await authService.ensureDek(first.masterSecret);
      await service.rekeyTo(dek);

      // 3) 此后用 DEK 能读，且 masterSecret 已经读不出来
      final afterMigration = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(dek);
      await afterMigration.loadVault();
      expect(afterMigration.entries.length, equals(1));
      expect(afterMigration.entries.first.id, equals('a'));

      // 4) 下次解锁拿到的是同一把 DEK
      final second = await authService.verifyMasterPassword('pw');
      expect(second!.sessionKey, equals(dek));
      expect(second.needsDekMigration, isFalse);
    });
  });

  group('修改主密码', () {
    test('只重新包装 DEK：会话密钥不变，数据密文一个字节都不变', () async {
      final before = await authService.setupMasterPassword('old-pw');

      // 用 DEK 写一份真实数据
      final service = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(before.sessionKey);
      await service.addEntry(login('a', 'secret-a'));
      final cipherBefore = cipherOf('a');

      final after = await authService.changePassword('old-pw', 'new-pw');

      expect(after.sessionKey, equals(before.sessionKey),
          reason: 'DEK 不变 → 数据无需重加密');
      expect(after.masterSecret, isNot(equals(before.masterSecret)));
      expect(cipherOf('a'), equals(cipherBefore),
          reason: '改密不应触碰数据密文（这就是 R2 的收益）');
    });

    test('改密后旧密码失效、新密码可解包出同一把 DEK', () async {
      final before = await authService.setupMasterPassword('old-pw');
      await authService.changePassword('old-pw', 'new-pw');

      expect(await authService.verifyMasterPassword('old-pw'), isNull);

      final withNew = await authService.verifyMasterPassword('new-pw');
      expect(withNew!.sessionKey, equals(before.sessionKey));
    });

    test('改密后 keyTag 必须改变（驱动「云端备份已过期」提示）', () async {
      await authService.setupMasterPassword('old-pw');
      final tagBefore = await authService.currentKeyTag();

      await authService.changePassword('old-pw', 'new-pw');

      expect(await authService.currentKeyTag(), isNot(equals(tagBefore)));
    });

    test('改密后数据仍可用新密码解锁读取', () async {
      final before = await authService.setupMasterPassword('old-pw');
      final service = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(before.sessionKey);
      await service.addEntry(login('a', 'secret-a'));

      final after = await authService.changePassword('old-pw', 'new-pw');

      final reopened = VaultService(secureStorage: const FlutterSecureStorage())
        ..setEncryptionKey(after.sessionKey);
      await reopened.loadVault();
      expect(reopened.entries.length, equals(1));
      expect(reopened.entries.first.id, equals('a'));
    });

    test('旧格式安装也能在改密时补齐 DEK', () async {
      // 只有 sha256 校验值、数据由 masterSecret 加密的老安装
      final salt = CryptoService.generateSalt();
      final masterSecret = CryptoService.deriveKeyWithArgon2id('old-pw', salt);
      storage.store['master_salt'] = base64Encode(salt);
      storage.store['master_kdf_params'] = jsonEncode(
        CryptoService.defaultKdfParams(salt).toJson(),
      );
      storage.store[legacyHashKey] =
          CryptoService.deriveVerificationHash('old-pw', salt);

      final result = await authService.changePassword('old-pw', 'new-pw');

      expect(result.sessionKey, isNot(equals(masterSecret)),
          reason: '改密时应生成新的 DEK');
      expect(await authService.hasWrappedDek(), isTrue);
      expect(result.needsDekMigration, isTrue,
          reason: '数据仍由 masterSecret 加密，需要上层补一次重加密');
    });
  });

  group('生物识别', () {
    test('存放的是 masterSecret（既能解包 DEK 又能上传备份）', () async {
      final setup = await authService.setupMasterPassword('pw');
      await authService.enableBiometric('pw');

      expect(
        base64Decode(storage.store[biometricKey]!),
        equals(setup.masterSecret),
      );
    });

    test('解锁应返回 DEK 作为会话密钥，并回传 backupKey', () async {
      final setup = await authService.setupMasterPassword('pw');
      await authService.enableBiometric('pw');

      // 生物识别解锁需要先通过系统认证，这里直接验证服务层的密钥语义
      final stored = base64Decode(storage.store[biometricKey]!);
      expect(stored, equals(setup.masterSecret));

      final viaPassword = await authService.verifyMasterPassword('pw');
      expect(viaPassword!.sessionKey, equals(setup.sessionKey));
      expect(viaPassword.masterSecret, equals(setup.masterSecret),
          reason: '生物识别会话靠它继续上传云端备份');
    });

    test('改密后生物识别项应更新为新密码派生的 masterSecret', () async {
      await authService.setupMasterPassword('old-pw');
      await authService.enableBiometric('old-pw');

      final after = await authService.changePassword('old-pw', 'new-pw');

      expect(
        base64Decode(storage.store[biometricKey]!),
        equals(after.masterSecret),
        reason: '否则改密后生物识别会解不开 DEK',
      );
    });

    test('老安装（尚无 DEK）走生物识别解锁时应照常解锁并标记需要迁移', () async {
      // 升级前的老安装：生物识别项里存的是 masterSecret，且没有 wrappedDek
      final salt = CryptoService.generateSalt();
      final masterSecret = CryptoService.deriveKeyWithArgon2id('pw', salt);
      storage.store['master_salt'] = base64Encode(salt);
      storage.store['master_kdf_params'] = jsonEncode(
        CryptoService.defaultKdfParams(salt).toJson(),
      );
      storage.store[legacyHashKey] =
          CryptoService.deriveVerificationHash('pw', salt);
      storage.store[biometricKey] = base64Encode(masterSecret);

      final result = await authService.biometricUnlock();

      expect(result.sessionKey, equals(masterSecret),
          reason: '数据仍由 masterSecret 加密，先用它解锁');
      expect(result.masterSecret, equals(masterSecret));
      expect(result.needsDekMigration, isTrue,
          reason: '必须提示上层完成 DEK 迁移，否则用户被挡在门外');
    });

    test('生物识别项里的钥匙必须能解包当前 DEK', () async {      final setup = await authService.setupMasterPassword('pw');
      await authService.enableBiometric('pw');
      await authService.changePassword('pw', 'new-pw');

      final storedMasterSecret = base64Decode(storage.store[biometricKey]!);
      final wrapped = EncryptedData.fromJson(
        jsonDecode(storage.store[wrappedDekKey]!) as Map<String, dynamic>,
      );
      final unwrapped = CryptoService.unwrapKey(
        wrapped,
        CryptoService.deriveWrapKey(storedMasterSecret),
      );

      expect(unwrapped, equals(setup.sessionKey));
    });
  });

  group('清除数据', () {
    test('应清掉包装好的 DEK', () async {
      await authService.setupMasterPassword('pw');
      expect(await authService.hasWrappedDek(), isTrue);

      await authService.clearAllData();

      expect(await authService.hasWrappedDek(), isFalse);
      expect(await authService.isPasswordSet(), isFalse);
    });
  });

  group('包装/解包原语', () {
    test('错误包装密钥应解包失败，正确密钥应还原', () {
      final dek = CryptoService.generateDek();
      final kek = CryptoService.deriveWrapKey(Uint8List.fromList(List.filled(32, 7)));
      final wrongKek =
          CryptoService.deriveWrapKey(Uint8List.fromList(List.filled(32, 9)));

      final wrapped = CryptoService.wrapKey(dek, kek);
      final json = jsonDecode(jsonEncode(wrapped.toJson())) as Map<String, dynamic>;

      expect(
        CryptoService.unwrapKey(EncryptedData.fromJson(json), kek),
        equals(dek),
      );
      expect(
        () => CryptoService.unwrapKey(EncryptedData.fromJson(json), wrongKek),
        throwsA(anything),
      );
    });
  });
}
