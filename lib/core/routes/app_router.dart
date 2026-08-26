import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/setup_password_page.dart';
import '../../features/auth/presentation/unlock_page.dart';
import '../../features/auth/presentation/biometric_settings_page.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/vault/presentation/vault_page.dart';
import '../../features/vault/presentation/add_entry_page.dart';
import '../../features/vault/presentation/entry_detail_page.dart';
import '../../features/vault/domain/vault_entry.dart';
import '../../features/sync/presentation/webdav_config_page.dart';
import '../../features/sync/presentation/webdav_sync_page.dart';

/// 应用路由配置
///
/// 使用 GoRouter 进行路由管理，并通过 AuthStatus 状态机实现显式路由守卫。
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final authStatus = AuthStatus.from(authState);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.uri.path;

      switch (authStatus) {
        case AuthStatusLoading():
          // 启动阶段仅允许停留在启动页
          return location == '/' ? null : '/';

        case AuthStatusUnlocked():
          // 已解锁时，将认证页面重定向到保险库
          if (location == '/' || location == '/setup' || location == '/unlock') {
            return '/vault';
          }
          return null;

        case AuthStatusLocked():
          // 已设置密码但未解锁，只允许进入解锁页
          return location != '/unlock' ? '/unlock' : null;

        case AuthStatusNeedsSetup():
          // 首次使用，仅开放设置页
          return location != '/setup' ? '/setup' : null;
      }
    },
    routes: [
      // 启动页
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),

      // 设置主密码页
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) => _fadePage(const SetupPasswordPage()),
      ),

      // 解锁页
      GoRoute(
        path: '/unlock',
        pageBuilder: (context, state) => _fadePage(const UnlockPage()),
      ),

      // 保险库主页
      GoRoute(
        path: '/vault',
        pageBuilder: (context, state) => _fadePage(const VaultPage()),
      ),

      // 添加条目页
      GoRoute(
        path: '/add',
        builder: (context, state) {
          final typeStr = state.uri.queryParameters['type'];
          final type = typeStr != null ? EntryType.values.firstWhere(
            (e) => e.name == typeStr,
            orElse: () => EntryType.login,
          ) : null;
          return AddEntryPage(initialEntryType: type);
        },
      ),

      // 条目详情页
      GoRoute(
        path: '/entry/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EntryDetailPage(entryId: id);
        },
      ),

      // 编辑条目页
      GoRoute(
        path: '/entry/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEntryPage(entryId: id);
        },
      ),

      // WebDAV 同步页
      GoRoute(
        path: '/webdav',
        builder: (context, state) => const WebDAVSyncPage(),
      ),

      // WebDAV 配置页
      GoRoute(
        path: '/webdav/config',
        builder: (context, state) => const WebDAVConfigPage(),
      ),

      // 生物识别设置页
      GoRoute(
        path: '/settings/biometric',
        builder: (context, state) => const BiometricSettingsPage(),
      ),
    ],

    // 错误页面
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '页面未找到',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.error?.toString() ?? '未知错误'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// 页面淡入过渡
Page<void> _fadePage(Widget child) => CustomTransitionPage<void>(
  child: child,
  transitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
);

/// 路由扩展方法
extension GoRouterExtension on BuildContext {
  /// 跳转到保险库主页
  void goToVault() => go('/vault');

  /// 跳转到解锁页
  void goToUnlock() => go('/unlock');

  /// 跳转到设置页
  void goToSetup() => go('/setup');

  /// 跳转到添加条目页
  void goToAddEntry({String? type}) {
    if (type != null) {
      go('/add?type=$type');
    } else {
      go('/add');
    }
  }

  /// 跳转到条目详情页
  void goToEntryDetail(String id) => go('/entry/$id');

  /// 跳转到编辑条目页
  void goToEditEntry(String id) => go('/entry/$id/edit');
}
