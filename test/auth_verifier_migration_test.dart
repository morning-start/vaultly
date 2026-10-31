import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/auth/data/auth_service.dart';
import 'package:vaultly_core/vaultly_core.dart';

import 'helpers/mock_secure_storage.dart';

/// R1：口令校验值加固与自动迁移
///
/// 契约：
/// - 新安装不再产生可离线爆破的 `sha256(password‖salt)`
/// - 旧安装解锁成功后**自动升级**并删除那个弱哈希
/// - `keyTag` 由 masterSecret 派生，解锁前后稳定（否则会误报备份过期）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;
  late AuthService authService;

  const legacyHashKey = 'master_password_hash';
  const verifierKey = 'master_verifier';
  const keyTagKey = 'master_key_tag';

  setUp(() {
    storage = MockSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    authService = AuthService(secureStorage: const FlutterSecureStorage());
  });

  /// 手工铺一个「升级前」的安装状态：只有 sha256 校验值 + 盐
  void seedLegacyInstall({required String password}) {
    final salt = CryptoService.generateSalt();
    storage.store['master_salt'] = base64Encode(salt);
    storage.store['master_kdf_params'] = jsonEncode(
      CryptoService.defaultKdfParams(salt).toJson(),
    );
    storage.store[legacyHashKey] =
        CryptoService.deriveVerificationHash(password, salt);
  }

  group('新安装', () {
    test('不应写入可被离线爆破的 sha256 校验值', () async {
      await authService.setupMasterPassword('master-password');

      expect(storage.store[legacyHashKey], isNull,
          reason: 'sha256(password‖salt) 是快速哈希，不应出现在新安装里');
      expect(storage.store[verifierKey], isNotNull);
      expect(storage.store[keyTagKey], isNotNull);
    });

    test('正确密码通过，错误密码返回 null 且不改变存储', () async {
      await authService.setupMasterPassword('master-password');
      final verifierBefore = storage.store[verifierKey];

      expect(await authService.verifyMasterPassword('master-password'),
          isNotNull);
      expect(await authService.verifyMasterPassword('wrong-password'), isNull);
      expect(storage.store[verifierKey], equals(verifierBefore));
    });

    test('isPasswordSet 应为 true', () async {
      await authService.setupMasterPassword('master-password');
      expect(await authService.isPasswordSet(), isTrue);
    });
  });

  group('旧格式迁移', () {
    test('旧安装用 sha256 校验，成功后升级并删除弱哈希', () async {
      seedLegacyInstall(password: 'legacy-password');
      expect(await authService.isPasswordSet(), isTrue,
          reason: '只有旧校验值时也应视为已设置密码');

      // 迁移前用错误密码不能通过
      expect(await authService.verifyMasterPassword('nope'), isNull);
      expect(storage.store[legacyHashKey], isNotNull,
          reason: '失败不应触发迁移');

      final key = await authService.verifyMasterPassword('legacy-password');
      expect(key, isNotNull);
      expect(storage.store[verifierKey], isNotNull, reason: '应写入 v2 校验值');
      expect(storage.store[keyTagKey], isNotNull, reason: '应写入指纹');
      expect(storage.store[legacyHashKey], isNull,
          reason: '弱哈希必须在迁移成功后删除，否则加固没有意义');
    });

    test('迁移后再解锁仍可用（幂等）', () async {
      seedLegacyInstall(password: 'legacy-password');
      await authService.verifyMasterPassword('legacy-password');

      expect(await authService.verifyMasterPassword('legacy-password'),
          isNotNull);
      expect(await authService.verifyMasterPassword('legacy-password'),
          isNotNull);
      expect(await authService.verifyMasterPassword('bad'), isNull);
    });

    test('迁移前后派生出的是同一把会话密钥（数据不会因此读不出来）', () async {
      seedLegacyInstall(password: 'legacy-password');
      final salt = base64Decode(storage.store['master_salt']!);
      final expected =
          CryptoService.deriveKeyWithArgon2id('legacy-password', salt);

      final migrated = await authService.verifyMasterPassword('legacy-password');
      expect(migrated, isNotNull);
      // 尚未完成 DEK 迁移：会话密钥仍是 masterSecret，数据可读
      expect(migrated!.sessionKey, equals(expected));
      expect(migrated.masterSecret, equals(expected));
      expect(migrated.needsDekMigration, isTrue,
          reason: '本机还没有 DEK，必须提示上层完成重加密');

      // 再次解锁同样得到 masterSecret（直到迁移真正完成）
      final again = await authService.verifyMasterPassword('legacy-password');
      expect(again!.sessionKey, equals(expected));
    });
  });

  group('密钥体系指纹 keyTag', () {
    test('应等于 HKDF(masterSecret, "vaultly/key-tag")', () async {
      await authService.setupMasterPassword('master-password');

      final params = await authService.getKdfParams();
      final masterSecret = CryptoService.deriveKeyWithKdfParams(
        'master-password',
        params,
      );

      expect(
        await authService.currentKeyTag(),
        equals(CryptoService.deriveKeyTag(masterSecret)),
      );
    });

    test('解锁前后必须稳定（否则每次解锁都误报「备份过期」）', () async {
      await authService.setupMasterPassword('master-password');
      final before = await authService.currentKeyTag();

      await authService.verifyMasterPassword('master-password');
      await authService.verifyMasterPassword('master-password');

      expect(await authService.currentKeyTag(), equals(before));
    });

    test('读取不需要主密码（生物识别会话同样可用）', () async {
      await authService.setupMasterPassword('master-password');
      final tag = await authService.currentKeyTag();
      expect(tag, isNotNull);
      expect(tag, isNotEmpty);
    });

    test('改主密码后必须改变', () async {
      await authService.setupMasterPassword('old-password');
      final before = await authService.currentKeyTag();

      await authService.changePassword('old-password', 'new-password');

      expect(await authService.currentKeyTag(), isNot(equals(before)));
    });

    test('未设置密码时为 null', () async {
      expect(await authService.currentKeyTag(), isNull);
    });

    test('迁移后指纹应已就位且可稳定读取', () async {
      seedLegacyInstall(password: 'legacy-password');
      expect(await authService.currentKeyTag(), isNull,
          reason: '迁移前本机还没有指纹');

      await authService.verifyMasterPassword('legacy-password');

      final tag = await authService.currentKeyTag();
      expect(tag, isNotNull);
      expect(await authService.currentKeyTag(), equals(tag));
    });
  });

  group('清除数据', () {
    test('应清掉校验值、指纹与遗留哈希', () async {
      seedLegacyInstall(password: 'legacy-password');
      await authService.verifyMasterPassword('legacy-password');
      // 制造一个遗留哈希，确认清除动作覆盖它
      storage.store[legacyHashKey] = 'leftover';

      await authService.clearAllData();

      expect(storage.store[verifierKey], isNull);
      expect(storage.store[keyTagKey], isNull);
      expect(storage.store[legacyHashKey], isNull);
      expect(await authService.isPasswordSet(), isFalse);
      expect(await authService.currentKeyTag(), isNull);
    });
  });
}
