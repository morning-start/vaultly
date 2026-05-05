import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/secure_text_field.dart';

class BiometricSettingsPage extends ConsumerStatefulWidget {
  const BiometricSettingsPage({super.key});

  @override
  ConsumerState<BiometricSettingsPage> createState() => _BiometricSettingsPageState();
}

class _BiometricSettingsPageState extends ConsumerState<BiometricSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enableBiometric() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    final success = await ref.read(authNotifierProvider.notifier).enableBiometric(password);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('生物识别已启用'),
          backgroundColor: Colors.green,
        ),
      );
      _passwordController.clear();
    }
    // 错误信息会通过 AuthState.error 自动显示
  }

  Future<void> _disableBiometric() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('禁用生物识别'),
        content: const Text('确定要禁用生物识别解锁吗？之后只能使用主密码解锁。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('禁用'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authNotifierProvider.notifier).disableBiometric();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('生物识别已禁用'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final biometricEnabled = authState.biometricAvailable;
    final biometricTypeName = authState.biometricTypeName ?? '生物识别';
    final biometricIcon = authState.biometricIcon ?? Icons.fingerprint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('生物识别设置'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // 图标和标题
                Icon(
                  biometricIcon,
                  size: 80,
                  color: biometricEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),

                const SizedBox(height: 16),
                Text(
                  biometricEnabled ? '$biometricTypeName 已启用' : '启用 $biometricTypeName',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),
                Text(
                  biometricEnabled
                      ? '您可以使用$biometricTypeName快速解锁保险库'
                      : '使用您手机的$biometricTypeName快速解锁保险库，无需重新录入指纹',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // 如果未启用，显示启用表单
                if (!biometricEnabled) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '启用步骤',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _buildStep(
                            context,
                            number: 1,
                            title: '验证身份',
                            description: '输入您的主密码验证身份',
                          ),
                          const SizedBox(height: 12),
                          _buildStep(
                            context,
                            number: 2,
                            title: '指纹认证',
                            description: '使用已注册的系统指纹完成认证',
                          ),
                          const SizedBox(height: 12),
                          _buildStep(
                            context,
                            number: 3,
                            title: '启用成功',
                            description: '之后可使用$biometricTypeName快速解锁',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SecureTextField(
                    controller: _passwordController,
                    labelText: '主密码',
                    hintText: '请输入主密码验证身份',
                    prefixIcon: Icons.lock,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主密码';
                      }
                      return null;
                    },
                    onSubmitted: (_) => _enableBiometric(),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: authState.isLoading ? null : _enableBiometric,
                    icon: Icon(biometricIcon),
                    label: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('启用 $biometricTypeName'),
                  ),
                ] else ...[
                  // 已启用状态
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$biometricTypeName 已启用，可用于快速解锁',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: _disableBiometric,
                    icon: const Icon(Icons.close),
                    label: const Text('禁用生物识别'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // 错误提示
                if (authState.error != null) ...[
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, {
    required int number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
