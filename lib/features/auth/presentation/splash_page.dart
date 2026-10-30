import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import '../../../shared/widgets/vault_dial.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';

/// 启动页
///
/// 与解锁页共用深靛黑底与表盘徽记，仅保留品牌名与初始化进度。
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.bgDeep,
      body: Stack(
        children: [
          Positioned(
            top: -160,
            left: -100,
            right: -100,
            child: IgnorePointer(
              child: Container(
                height: 420,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withAlpha(40),
                      colorScheme.primary.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: AppTokens.easeOutBack,
                  builder: (context, value, child) => Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.scale(scale: value, child: child),
                  ),
                  child: const VaultDial(size: 104, icon: Icons.shield_rounded),
                ),
                const SizedBox(height: AppTokens.spaceXL),
                Text(
                  'Vaultly',
                  style: textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  '安全可靠的密码管理器',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.textMuted,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXXXL),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
