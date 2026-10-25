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
import '../../features/vault/presentation/favorites_page.dart';
import '../../features/vault/presentation/add_entry_page.dart';
import '../../features/vault/presentation/entry_detail_page.dart';
import '../../features/vault/domain/vault_entry.dart';
import '../../features/tools/presentation/tools_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/auth_lock_bridge.dart';
import '../../features/sync/presentation/webdav_config_page.dart';
import '../../features/sync/presentation/webdav_sync_page.dart';

/// 应用路由配置
///
/// 使用 GoRouter 进行路由管理，并通过 AuthStatus 状态机实现显式路由守卫。
/// 解锁后的主界面采用 StatefulShellRoute 底部四 Tab 结构
/// （保险库 / 收藏 / 工具 / 设置），各 Tab 状态独立保持。
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final authStatus = AuthStatus.from(authState);

  // 将真实锁定动作注入设置页的锁定桥（settings 不反向依赖 auth）。
  // 延迟到微任务执行：Provider 初始化期间不允许修改其他 Provider。
  Future.microtask(() {
    ref.read(authLockBridgeProvider.notifier).state = () {
      ref.read(authNotifierProvider.notifier).lock();
    };
  });

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
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

      // 主界面：底部四 Tab
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vault',
                pageBuilder: (context, state) =>
                    _fadePage(const VaultPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                pageBuilder: (context, state) =>
                    _fadePage(const FavoritesPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tools',
                pageBuilder: (context, state) =>
                    _fadePage(const ToolsPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                routes: [
                  GoRoute(
                    path: 'biometric',
                    builder: (context, state) =>
                        const BiometricSettingsPage(),
                  ),
                ],
                pageBuilder: (context, state) =>
                    _fadePage(const SettingsPage()),
              ),
            ],
          ),
        ],
      ),

      // 添加条目页（全屏推入，不进 shell）
      GoRoute(
        path: '/add',
        pageBuilder: (context, state) {
          final typeStr = state.uri.queryParameters['type'];
          final type = typeStr != null
              ? EntryType.values.firstWhere(
                  (e) => e.name == typeStr,
                  orElse: () => EntryType.login,
                )
              : null;
          return _slideUpPage(AddEntryPage(initialEntryType: type));
        },
      ),

      // 条目详情页
      GoRoute(
        path: '/entry/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _fadePage(EntryDetailPage(entryId: id));
        },
      ),

      // 编辑条目页
      GoRoute(
        path: '/entry/:id/edit',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _slideUpPage(AddEntryPage(entryId: id));
        },
      ),

      // WebDAV 同步页（保留旧路径，设置中心跳转）
      GoRoute(
        path: '/webdav',
        pageBuilder: (context, state) => _fadePage(const WebDAVSyncPage()),
      ),

      // WebDAV 配置页
      GoRoute(
        path: '/webdav/config',
        pageBuilder: (context, state) => _fadePage(const WebDAVConfigPage()),
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

/// 主界面外壳：底部导航 + 各 Tab 内容
class _HomeShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _HomeShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: Icon(
              Icons.shield_rounded,
              color: colorScheme.primary,
            ),
            label: '保险库',
          ),
          const NavigationDestination(
            icon: Icon(Icons.star_border_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: '收藏',
          ),
          const NavigationDestination(
            icon: Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction_rounded),
            label: '工具',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 页面淡入过渡
Page<void> _fadePage(Widget child) => CustomTransitionPage<void>(
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// 底部上滑过渡（创建流页面）
Page<void> _slideUpPage(Widget child) => CustomTransitionPage<void>(
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
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
