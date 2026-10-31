import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/sync/domain/sync_orchestrator.dart';
import 'package:vaultly/features/sync/presentation/sync_providers.dart';
import 'package:vaultly/features/sync/presentation/webdav_sync_page.dart';
import 'package:vaultly/ui/theme/app_theme.dart';

import 'helpers/mock_secure_storage.dart';

/// 假的同步编排器：不碰网络，直接返回所需状态
class _FakeSyncOrchestrator extends SyncOrchestrator {
  _FakeSyncOrchestrator({required this.stale});

  final bool stale;

  @override
  Future<bool> isConfigured() async => true;

  @override
  Future<DateTime?> getLastSyncTime() async => null;

  @override
  Future<bool> checkRemoteBackup() async => true;

  @override
  Future<bool> isRemoteBackupStale({required String? currentKeyTag}) async =>
      stale;
}

/// 同步页「备份已过期」提示的渲染测试
///
/// 这条提示是「当前主密码一定能打开云端备份」这个契约的最后一道防线：
/// 改过主密码后如果不同步页不提示，用户会一直以为备份能恢复。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = MockSecureStorage();
  });

  /// 不用 pumpAndSettle：页面在检查备份时可能带持续动画，
  /// 手动推几帧即可让 Future 落地并完成重建。
  ///
  /// 视口调高是为了让 ListView 一次性铺完整页内容（底部说明文案在
  /// 懒加载区域之外，默认视口下不会被构建）。
  Future<void> pumpPage(WidgetTester tester, {required bool stale}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webDAVServiceProvider.overrideWithValue(
            _FakeSyncOrchestrator(stale: stale),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WebDAVSyncPage(),
        ),
      ),
    );

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('云端备份过期时应显示警示卡与重新上传入口', (tester) async {
    await pumpPage(tester, stale: true);

    expect(find.text('云端备份还是旧主密码加密的'), findsOneWidget);
    expect(find.text('用当前主密码重新上传'), findsOneWidget);
  });

  testWidgets('备份新鲜时不应显示警示卡', (tester) async {
    await pumpPage(tester, stale: false);

    expect(find.text('云端备份还是旧主密码加密的'), findsNothing);
    expect(find.text('用当前主密码重新上传'), findsNothing);
  });

  testWidgets('底部说明应写明「任何设备用同一主密码都能解开」', (tester) async {
    await pumpPage(tester, stale: false);

    expect(find.textContaining('任何设备用同一个主密码都能解开'), findsOneWidget);
  });
}
