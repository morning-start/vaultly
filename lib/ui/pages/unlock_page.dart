import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/secure_text_field.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
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
    final biometricAvailable = authState.biometricAvailable;
    final isAuthenticating = authState.isAuthenticatingWithBiometric;
    final biometricTypeName = authState.biometricTypeName ?? '生物识别';
    final biometricIcon = authState.biometricIcon ?? Icons.fingerprint;

    return Scaffold(
      appBar: AppBar(title: const Text('解锁保险库')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // 主图标（根据状态切换）
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isAuthenticating
                      ? Icon(
                          biometricIcon,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary.withAlpha(153),
                        )
                      : Icon(
                          Icons.lock_open,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),

                const SizedBox(height: 24),
                Text(
                  '欢迎回来',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isAuthenticating
                      ? '正在验证$biometricTypeName...'
                      : '请输入主密码来解锁您的保险库',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // 密码输入框（生物识别认证时不禁用，允许同时使用）
                SecureTextField(
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

                const SizedBox(height: 16),

                // 生物识别按钮区域
                if (biometricAvailable && !isAuthenticating)
                  _buildBiometricButton(biometricTypeName, biometricIcon)
                else if (isAuthenticating)
                  _buildAuthenticatingIndicator(biometricTypeName),

                const SizedBox(height: 24),

                // 错误提示
                if (authState.error != null && !isAuthenticating) ...[
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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

                // 提示文字
                if (biometricAvailable) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _biometricUnlock,
                      icon: Icon(biometricIcon, size: 18),
                      label: Text('使用$biometricTypeName'),
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
