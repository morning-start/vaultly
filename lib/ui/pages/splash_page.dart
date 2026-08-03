import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../theme/tokens.dart';

/// 启动页
///
/// 显示应用 Logo 和加载指示器
/// 导航逻辑由路由守卫处理，此页面仅负责显示 UI
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听认证状态，用于调试（可选）
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withAlpha(140),
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppTokens.animSlow,
            curve: Curves.easeOut,
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withAlpha(220),
                    shape: BoxShape.circle,
                    boxShadow: AppTokens.cardShadow(
                      Colors.black.withAlpha(isDark(colorScheme) ? 64 : 28),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.spaceL),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXL),
                Text(
                  'Vaultly',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  '安全可靠的密码管理器',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXXL),
                const CircularProgressIndicator(),
                // 调试信息（仅在开发时显示）
                if (authState.isLoading) ...[
                  const SizedBox(height: AppTokens.spaceL),
                  Text(
                    '正在初始化...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isDark(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.dark;
}
