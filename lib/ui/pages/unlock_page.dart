import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/secure_text_field.dart';
import '../theme/tokens.dart';

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

  /// 错误抖动偏移：衰减正弦波
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
    // 延迟一帧后检查是否自动弹出指纹认证
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoTriggerBiometricIfAvailable();
    });
  }

  /// 当生物识别已启用时，自动弹出系统指纹对话框
  /// 类似于 1Password / Bitwarden 等密码管理器的行为
  void _autoTriggerBiometricIfAvailable() {
    if (_autoBiometricAttempted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.biometricAvailable && !authState.isAuthenticatingWithBiometric) {
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
    final success = await ref.read(authNotifierProvider.notifier).unlock(password);

    if (!mounted) return;

    if (success) {
      context.go('/vault');
    } else {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码错误，请重试'), backgroundColor: Colors.red),
      );
      _passwordController.clear();
    }
  }

  /// 使用生物识别解锁
  Future<void> _biometricUnlock() async {
    final authState = ref.read(authNotifierProvider);

    // 如果正在认证中，不重复触发
    if (authState.isAuthenticatingWithBiometric) return;

    final success = await ref.read(authNotifierProvider.notifier).unlockWithBiometric();

    if (!mounted) return;

    if (success) {
      context.go('/vault');
    }
    // 错误信息会通过 AuthState.error 自动显示
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
      appBar: AppBar(title: const Text('解锁保险库')),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.spaceXL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppTokens.spaceXXL),

                  // 品牌 Logo 徽章（根据状态切换）
                  AnimatedSwitcher(
                    duration: AppTokens.animNormal,
                    child: isAuthenticating
                        ? Container(
                            key: const ValueKey('authenticating'),
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primaryContainer,
                            ),
                            child: Icon(
                              biometricIcon,
                              size: 44,
                              color: colorScheme.primary,
                            ),
                          )
                        : Container(
                            key: const ValueKey('logo'),
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.surface.withAlpha(220),
                              boxShadow: AppTokens.cardShadow(
                                Colors.black.withAlpha(32),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTokens.spaceL),
                              child: Image.asset('assets/logo.png'),
                            ),
                          ),
                  ),

                  const SizedBox(height: AppTokens.spaceXL),
                  Text(
                    '欢迎回来',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  Text(
                    isAuthenticating
                        ? '正在验证$biometricTypeName...'
                        : '请输入主密码来解锁您的保险库',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTokens.spaceXL),

                  // 密码输入框（错误时抖动反馈）
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeOffset, 0),
                      child: child,
                    ),
                    child: SecureTextField(
                      controller: _passwordController,
                    labelText: '主密码',
                    hintText: '请输入主密码',
                    prefixIcon: Icons.lock,
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

                  const SizedBox(height: AppTokens.spaceL),

                  // 错误提示
                  if (authState.error != null && !isAuthenticating) ...[
                    Card(
                      color: colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.spaceM),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: AppTokens.spaceS),
                            Expanded(
                              child: Text(
                                authState.error!,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceL),
                  ],

                  ElevatedButton(
                    onPressed: (authState.isLoading || isAuthenticating) ? null : _unlock,
                    child: authState.isLoading || isAuthenticating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('解锁'),
                  ),

                  // 生物识别按钮区域（只显示一个）
                  if (biometricAvailable) ...[
                    const SizedBox(height: AppTokens.spaceL),
                    if (isAuthenticating)
                      _buildAuthenticatingIndicator(biometricTypeName)
                    else
                      _buildBiometricButton(biometricTypeName, biometricIcon),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建生物识别按钮
  Widget _buildBiometricButton(String typeName, IconData icon) {
    return Center(
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          InkWell(
            onTap: _biometricUnlock,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(100),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '使用$typeName 解锁',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建正在认证指示器
  Widget _buildAuthenticatingIndicator(String typeName) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '正在验证$typeName...',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
