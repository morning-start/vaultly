import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/auth/data/auth_service.dart';
import 'package:vaultly/features/sync/data/sync_config_repository.dart';
import 'package:vaultly/features/sync/domain/sync_orchestrator.dart';

import 'helpers/mock_secure_storage.dart';

/// 云端备份新鲜度测试
///
/// 契约：**当前正在使用的主密码，一定能打开云端备份**。
///
/// 唯一会打破它的情况是「改过主密码」：那时云端那份备份是旧密码加密的，
/// 只有旧密码能解开。这里保证该情况能被可靠地检测出来并提示用户重新上传。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;
  late AuthService authService;

  setUp(() {
    storage = MockSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    authService = AuthService(secureStorage: const FlutterSecureStorage());
  });

  group('密钥指纹 currentKeyTag', () {
    test('未设置主密码时应为 null', () async {
      expect(await authService.currentKeyTag(), isNull);
    });

    test('同一个主密码在多次解锁之间应保持稳定', () async {
      await authService.setupMasterPassword('master-password');
      final tag = await authService.currentKeyTag();
      expect(tag, isNotNull);

      // 解锁不会改变密钥体系，指纹必须不变，否则会误报「备份过期」
      final key = await authService.verifyMasterPassword('master-password');
      expect(key, isNotNull);
      expect(await authService.currentKeyTag(), equals(tag));
    });

    test('改主密码后指纹必须改变（这正是「备份已过期」的判据）', () async {
      await authService.setupMasterPassword('old-password');
      final oldTag = await authService.currentKeyTag();

      await authService.changePassword('old-password', 'new-password');
      final newTag = await authService.currentKeyTag();

      expect(newTag, isNot(equals(oldTag)));
    });

    test('指纹不应等于落盘的口令校验哈希本身', () async {
      await authService.setupMasterPassword('master-password');
      final tag = await authService.currentKeyTag();

      expect(tag, isNot(equals(storage.store['master_password_hash'])));
    });
  });

  group('云端备份新鲜度判定', () {
    SyncOrchestrator orchestratorWith(SyncConfigRepository repo) =>
        SyncOrchestrator(configRepository: repo);

    SyncConfigRepository freshRepo() =>
        SyncConfigRepository(secureStorage: const FlutterSecureStorage());

    test('未记录指纹时不应判定为过期（旧版本上传，避免误报）', () async {
      final orchestrator = orchestratorWith(freshRepo());

      expect(
        await orchestrator.isRemoteBackupStale(currentKeyTag: 'tag-a'),
        isFalse,
      );
    });

    test('当前指纹为 null（未设置密码）时不应判定为过期', () async {
      final repo = freshRepo();
      await repo.updateLastUploadKeyTag('tag-a');

      expect(
        await orchestratorWith(repo).isRemoteBackupStale(currentKeyTag: null),
        isFalse,
      );
    });

    test('指纹一致时不应判定为过期', () async {
      final repo = freshRepo();
      await repo.updateLastUploadKeyTag('tag-a');

      expect(
        await orchestratorWith(repo).isRemoteBackupStale(currentKeyTag: 'tag-a'),
        isFalse,
      );
    });

    test('指纹不一致（改过主密码）应判定为过期', () async {
      final repo = freshRepo();
      await repo.updateLastUploadKeyTag('tag-old');

      expect(
        await orchestratorWith(repo)
            .isRemoteBackupStale(currentKeyTag: 'tag-new'),
        isTrue,
      );
    });

    test('旧方案（无前缀）写入的指纹应视为未知，避免升级后误报过期', () async {
      // v4.0.1 及更早：指纹是「校验值的再哈希」，直接写字符串、没有方案前缀。
      // R1 把指纹来源改成 HKDF(masterSecret) 后，旧值不再可比。
      storage.store['webdav_last_upload_key_tag'] = 'old-scheme-tag';

      final repo = freshRepo();
      expect(await repo.getLastUploadKeyTag(), isNull,
          reason: '方案不匹配的旧值必须当作未知');

      expect(
        await orchestratorWith(repo)
            .isRemoteBackupStale(currentKeyTag: 'new-scheme-tag'),
        isFalse,
        reason: '宁可漏报也不能误报——误报会把用户引向一次无意义的重传',
      );
    });

    test('新方案写入的指纹应能正常往返比对', () async {
      final repo = freshRepo();
      await repo.updateLastUploadKeyTag('tag-a');

      expect(await repo.getLastUploadKeyTag(), equals('tag-a'));
      expect(
        await orchestratorWith(repo).isRemoteBackupStale(currentKeyTag: 'tag-a'),
        isFalse,
      );
    });

    test('清除 WebDAV 配置后指纹记录也应被清除', () async {
      final repo = freshRepo();
      await repo.updateLastUploadKeyTag('tag-a');
      expect(await repo.getLastUploadKeyTag(), equals('tag-a'));

      await repo.clearConfig();
      expect(await repo.getLastUploadKeyTag(), isNull);
    });

    test('改主密码后完整链路应能发现云端备份已过期', () async {
      // 1. 设密码 → 上传（记录当时的指纹）
      await authService.setupMasterPassword('old-password');
      final repo = freshRepo();
      await repo.updateLastUploadKeyTag((await authService.currentKeyTag())!);

      final orchestrator = orchestratorWith(repo);
      expect(
        await orchestrator
            .isRemoteBackupStale(currentKeyTag: await authService.currentKeyTag()),
        isFalse,
        reason: '刚上传过，此时不应提示过期',
      );

      // 2. 改主密码 → 云端那份变成旧密码加密的
      await authService.changePassword('old-password', 'new-password');

      expect(
        await orchestrator
            .isRemoteBackupStale(currentKeyTag: await authService.currentKeyTag()),
        isTrue,
        reason: '改密后必须提示重新上传，否则当前主密码打不开云端备份',
      );

      // 3. 用新密码重新上传 → 提示消失
      await repo.updateLastUploadKeyTag((await authService.currentKeyTag())!);
      expect(
        await orchestrator
            .isRemoteBackupStale(currentKeyTag: await authService.currentKeyTag()),
        isFalse,
      );
    });
  });
}
