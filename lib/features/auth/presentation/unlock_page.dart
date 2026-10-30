import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_providers.dart';
import '../../../shared/widgets/secure_text_field.dart';
import '../../../shared/widgets/vault_dial.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';

/// 解锁页（原型 unlock.html）
///
/// 结构：保险库表盘徽记 → 欢迎标题与引导语 → 主密码输入（抖动反馈）
/// → 解锁按钮 → 「或者」分隔 → 生物识别圆形入口。
class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final AnimationController _shakeController;
  bool _autoBiometricAttempted = false;

  double get _shakeOffset {
    final value = _shakeController.value;
    if (value == 0) return 0;
    return math.sin(value * math.pi * 4) * 10 * (1 - value);
  }

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoTriggerBiometricIfAvailable();
    });
  }

  void _autoTriggerBiometricIfAvailable() {
    if (_autoBiometricAttempted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.biometricAvailable &&
        !authState.isAuthenticatingWithBiometric) {
      _autoBiometricAttempted = true;
      _biometricUnlock();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    final success = await ref
        .read(authNotifierProvider.notifier)
        .unlock(password);

    if (!mounted) return;

    if (success) {
      context.go('/vault');
    } else {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码错误，请重试')));
      _passwordController.clear();
    }
  }

  Future<void> _biometricUnlock() async {
    final authState = ref.read(authNotifierProvider);

    if (authState.isAuthenticatingWithBiometric) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .unlockWithBiometric();

    if (!mounted) return;

    if (success) {
      context.go('/vault');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final biometricAvailable = authState.biometricAvailable;
    final isAuthenticating = authState.isAuthenticatingWithBiometric;
    final biometricTypeName = authState.biometricTypeName ?? '生物识别';
    final biometricIcon = authState.biometricIcon ?? Icons.fingerprint;

    return Scaffold(
      backgroundColor: colorScheme.bgDeep,
      body: Stack(
        children: [
          // 主色径向光晕（原型 .dial-glow）
          Positioned(
            top: -160,
            left: -100,
            right: -100,
            child: IgnorePointer(
              child: Container(
                height: 460,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withAlpha(44),
                      colorScheme.primary.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: VaultDial(size: 128)),
                        const SizedBox(height: 28),
                        Text(
                          '欢迎回来',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAuthenticating
                              ? '正在验证$biometricTypeName…'
                              : '输入主密码，打开你的保险库',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          '主密码',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            color: colorScheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceS),
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_shakeOffset, 0),
                            child: child,
                          ),
                          child: SecureTextField(
                            controller: _passwordController,
                            hintText: '••••••••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            autofocus: !isAuthenticating,
                            enabled: !isAuthenticating,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入密码';
                              }
                              return null;
                            },
                            onSubmitted: (_) => _unlock(),
                          ),
                        ),
                        if (authState.error != null && !isAuthenticating) ...[
                          const SizedBox(height: AppTokens.spaceM),
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colorScheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: AppTokens.spaceS),
                              Expanded(
                                child: Text(
                                  authState.error!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppTokens.spaceM),
                        FilledButton(
                          onPressed: (authState.isLoading || isAuthenticating)
                              ? null
                              : _unlock,
                          child: authState.isLoading || isAuthenticating
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('解锁保险库'),
                                    SizedBox(width: AppTokens.spaceS),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                        ),
                        if (biometricAvailable) ...[
                          const SizedBox(height: 24),
                          _OrDivider(text: '或者', colorScheme: colorScheme),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: isAuthenticating
                                        ? null
                                        : _biometricUnlock,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colorScheme.surfaceCard,
                                        border: Border.all(
                                          color: colorScheme.hairlineStrong,
                                        ),
                                      ),
                                      child: isAuthenticating
                                          ? const Padding(
                                              padding: EdgeInsets.all(18),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              biometricIcon,
                                              size: 30,
                                              color: colorScheme.primary,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isAuthenticating
                                      ? '正在验证$biometricTypeName…'
                                      : '使用$biometricTypeName解锁',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「或者」分隔行
class _OrDivider extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;

  const _OrDivider({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: colorScheme.textMuted),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.hairline)),
      ],
    );
  }
}
