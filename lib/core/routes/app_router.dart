import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/pages/splash_page.dart';
import '../../ui/pages/setup_password_page.dart';
import '../../ui/pages/unlock_page.dart';
import '../../ui/pages/vault_page.dart';
import '../../ui/pages/add_entry_page.dart';
import '../../ui/pages/entry_detail_page.dart';
import '../providers/auth_provider.dart';
import '../models/vault_entry.dart';

/// 应用路由配置
///
/// 参考文档: wiki/06-开发计划/任务清单.md T004
/// 使用 GoRouter 进行路由管理
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isUnlocked;
      final isPasswordSet = authState.isPasswordSet;
      final isLoading = authState.isLoading;

      final location = state.uri.path;

      // 加载中：如果在启动页则停留，否则不处理
      if (isLoading) {
        if (location == '/') return null;
        // 加载期间不允许访问其他页面，回到启动页等待
        return '/';
      }

      // 已解锁状态
      if (isAuthenticated) {
        // 已解锁用户不能访问启动页、设置页、解锁页
        if (location == '/' || location == '/setup' || location == '/unlock') {
          return '/vault';
        }
        return null;
      }

      // 未解锁状态
      if (isPasswordSet) {
        // 已设置密码但未解锁，只能访问解锁页
        if (location != '/unlock') {
          return '/unlock';
        }
        return null;
      }

      // 未设置密码状态
      // 只能访问设置页
      if (location != '/setup') {
        return '/setup';
      }

      return null;
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
        builder: (context, state) => const SetupPasswordPage(),
      ),

      // 解锁页
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const UnlockPage(),
      ),

      // 保险库主页
      GoRoute(
        path: '/vault',
        builder: (context, state) => const VaultPage(),
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
