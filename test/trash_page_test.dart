import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/features/vault/data/vault_service.dart';
import 'package:vaultly_core/vaultly_core.dart';
import 'package:vaultly/features/vault/presentation/trash_page.dart';
import 'package:vaultly/features/vault/presentation/vault_providers.dart';
import 'package:vaultly/ui/theme/app_theme.dart';

import 'helpers/mock_secure_storage.dart';

/// 回收站 UI 与「墓碑不出现在正常列表里」的渲染测试
///
/// ADR-006 §10 F7：R3 的墓碑如果没配套界面，用户既恢复不了也清不掉，
/// 而且删除后的条目一旦泄漏到正常列表里就是直接的隐私问题。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorage storage;

  setUp(() {
    storage = MockSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    VaultService.reset();
  });

  tearDown(() {
    VaultService.reset();
  });

  VaultEntry login(String id, String title) => LoginEntry(
    id: id,
    title: title,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    username: 'alice',
    password: 'P@ss!',
  );

  /// 建一个「1 个活跃条目 + 1 个已删除条目」的容器
  Future<ProviderContainer> seededContainer() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(vaultNotifierProvider.notifier);
    await notifier.unlock(testKey());
    await notifier.addEntry(login('live-id', '正常条目'));
    await notifier.addEntry(login('gone-id', '被删条目'));
    await notifier.deleteEntry('gone-id');

    return container;
  }

  Future<void> pumpTrash(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await seededContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const TrashPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('回收站列出已删除条目，并提供恢复与彻底删除', (tester) async {
    await pumpTrash(tester);

    expect(find.text('被删条目'), findsOneWidget);
    expect(find.text('正常条目'), findsNothing, reason: '回收站不该列出活跃条目');
    expect(find.textContaining('剩余 30 天'), findsOneWidget);
    expect(find.byTooltip('恢复'), findsOneWidget);
    expect(find.byTooltip('彻底删除'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
  });

  testWidgets('恢复后条目离开回收站，回到活跃列表', (tester) async {
    await pumpTrash(tester);

    await tester.tap(find.byTooltip('恢复'));
    await tester.pump();
    // 恢复会弹一个轻提示（1.6s 后自动消失），把它的计时器走完，
    // 否则测试结束时会被判定为「有未完成的 Timer」。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('回收站是空的'), findsOneWidget);
  });

  testWidgets('回收站为空时给出空状态说明', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(vaultNotifierProvider.notifier).unlock(testKey());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const TrashPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('回收站是空的'), findsOneWidget);
    expect(find.textContaining('30 天后自动清除'), findsWidgets);
  });

  testWidgets('墓碑不会出现在条目列表、搜索与统计里', (tester) async {
    final container = await seededContainer();

    expect(container.read(vaultEntriesProvider).map((e) => e.id), ['live-id']);
    expect(container.read(vaultSearchProvider('')).map((e) => e.id), [
      'live-id',
    ]);
    expect(container.read(vaultStatsProvider)['total'], 1);
    expect(container.read(vaultTrashedEntriesProvider).map((e) => e.id), [
      'gone-id',
    ]);

    // 含墓碑的全量列表是同步用的，必须仍然带着删除记录
    expect(container.read(vaultNotifierProvider).allEntries, hasLength(2));
    expect(container.read(vaultNotifierProvider).trashCount, 1);
  });
}
