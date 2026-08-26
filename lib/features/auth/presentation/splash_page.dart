import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import '../../../ui/theme/tokens.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6366F1).withAlpha(40),
              const Color(0xFF8B5CF6).withAlpha(20),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 浮动 Logo 动画容器
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: AppTokens.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: value,
                    child: child,
                  ),
                ),
                child: Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(AppTokens.spaceL),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppTokens.cardShadow(
                      const Color(0xFF6366F1),
                      opacity: 0.15,
                    ),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(30),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png'),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceXL),
              Text(
                'Vaultly',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(height: AppTokens.spaceS),
              Text(
                '安全可靠的密码管理器',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: AppTokens.spaceXXXL),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ),
              ),
              if (authState.isLoading) ...[
                const SizedBox(height: AppTokens.spaceL),
                Text(
                  '正在初始化...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withAlpha(180),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
