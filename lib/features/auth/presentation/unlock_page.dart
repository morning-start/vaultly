import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_providers.dart';
import '../../../shared/widgets/secure_text_field.dart';
import '../../../ui/theme/tokens.dart';

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
    final success =
        await ref.read(authNotifierProvider.notifier).unlock(password);

    if (!mounted) return;

    if (success) {
      context.go('/vault');
    } else {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('密码错误，请重试'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
      );
      _passwordController.clear();
    }
  }

  Future<void> _biometricUnlock() async {
    final authState = ref.read(authNotifierProvider);

    if (authState.isAuthenticatingWithBiometric) return;

    final success =
        await ref.read(authNotifierProvider.notifier).unlockWithBiometric();

    if (!mounted) return;

    if (success) {
      context.go('/vault');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final biometricAvailable = authState.biometricAvailable;
    final isAuthenticating = authState.isAuthenticatingWithBiometric;
    final biometricTypeName = authState.biometricTypeName ?? '生物识别';
    final biometricIcon = authState.biometricIcon ?? Icons.fingerprint;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withAlpha(30),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spaceXL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTokens.spaceXXL),

                    // Logo
                    Center(
                      child: AnimatedSwitcher(
                        duration: AppTokens.animNormal,
                        child: isAuthenticating
                            ? Container(
                                key: const ValueKey('authenticating'),
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primaryContainer,
                                  border: Border.all(
                                    color: colorScheme.primary.withAlpha(60),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  biometricIcon,
                                  size: 40,
                                  color: colorScheme.primary,
                                ),
                              )
                            : Container(
                                key: const ValueKey('logo'),
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.surface,
                                  boxShadow: AppTokens.cardShadow(
                                    colorScheme.primary,
                                    opacity: 0.1,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.primary.withAlpha(25),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppTokens.spaceL),
                                  child: Image.asset('assets/logo.png'),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: AppTokens.spaceXL),

                    // 标题
                    Text(
                      '欢迎回来',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTokens.spaceS),

                    Text(
                      isAuthenticating
                          ? '正在验证$biometricTypeName...'
                          : '请输入主密码来解锁您的保险库',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTokens.spaceXXL),

                    // 密码输入框（带抖动动画）
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeOffset, 0),
                        child: child,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTokens.radiusL),
                          boxShadow: isAuthenticating
                              ? null
                              : AppTokens.cardShadow(
                                  colorScheme.outline,
                                  opacity: 0.05,
                                ),
                        ),
                        child: SecureTextField(
                          controller: _passwordController,
                          labelText: '主密码',
                          hintText: '请输入主密码',
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
                    ),

                    const SizedBox(height: AppTokens.spaceL),

                    // 错误提示
                    if (authState.error != null && !isAuthenticating)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppTokens.spaceS),
                            Expanded(
                              child: Text(
                                authState.error!,
                                style: TextStyle(color: colorScheme.errorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 解锁按钮
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                        gradient: (authState.isLoading || isAuthenticating)
                            ? null
                            : AppTokens.primaryGradient,
                        color: (authState.isLoading || isAuthenticating)
                            ? colorScheme.surfaceContainerHighest
                            : null,
                        boxShadow: (authState.isLoading || isAuthenticating)
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withAlpha(100),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed:
                            (authState.isLoading || isAuthenticating) ? null : _unlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.spaceM,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radiusM),
                          ),
                        ),
                        child: authState.isLoading || isAuthenticating
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            : const Text(
                                '解锁',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    // 生物识别
                    if (biometricAvailable) ...[
                      const SizedBox(height: AppTokens.spaceXL),
                      if (isAuthenticating)
                        Center(
                          child: Column(
                            children: [
                              const SizedBox(height: AppTokens.spaceS),
                              Text(
                                '正在验证$biometricTypeName...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            children: [
                              const Divider(),
                              const SizedBox(height: AppTokens.spaceL),
                              InkWell(
                                onTap: _biometricUnlock,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(AppTokens.spaceL),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTokens.primaryGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withAlpha(120),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                    child: Icon(
                                    biometricIcon,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTokens.spaceS),
                              Text(
                                '使用$biometricTypeName 解锁',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
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
    );
  }
}

