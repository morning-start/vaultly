import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import '../../../shared/widgets/secure_text_field.dart';
import '../../../ui/theme/tokens.dart';

class BiometricSettingsPage extends ConsumerStatefulWidget {
  const BiometricSettingsPage({super.key});

  @override
  ConsumerState<BiometricSettingsPage> createState() =>
      _BiometricSettingsPageState();
}

class _BiometricSettingsPageState
    extends ConsumerState<BiometricSettingsPage> {
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
    final success =
        await ref.read(authNotifierProvider.notifier).enableBiometric(password);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('生物识别已启用'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
      );
      _passwordController.clear();
    }
  }

  Future<void> _disableBiometric() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('禁用生物识别'),
        content: const Text('确定要禁用生物识别解锁吗？之后只能使用主密码解锁。'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXL),
        ),
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
          SnackBar(
            content: const Text('生物识别已禁用'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusM),
            ),
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
          padding: const EdgeInsets.all(AppTokens.spaceXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTokens.spaceXL),

                // 大图标
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: biometricEnabled
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF6366F1).withAlpha(60),
                                const Color(0xFF8B5CF6).withAlpha(30),
                              ],
                            )
                          : null,
                      color: biometricEnabled
                          ? null
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: biometricEnabled
                            ? const Color(0xFF6366F1).withAlpha(50)
                            : Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withAlpha(80),
                        width: 2,
                      ),
                      boxShadow: biometricEnabled
                          ? AppTokens.cardShadow(
                              const Color(0xFF6366F1), opacity: 0.1)
                          : null,
                    ),
                    child: Icon(
                      biometricIcon,
                      size: 40,
                      color: biometricEnabled
                          ? const Color(0xFF6366F1)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: AppTokens.spaceL),

                Text(
                  biometricEnabled
                      ? '$biometricTypeName 已启用'
                      : '启用 $biometricTypeName',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTokens.spaceS),

                Text(
                  biometricEnabled
                      ? '您可以使用$biometricTypeName快速解锁保险库'
                      : '使用您手机的$biometricTypeName快速解锁保险库，无需重新录入指纹',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTokens.spaceXXL),

                if (!biometricEnabled) ...[
                  // 启用流程卡片
                  Container(
                    padding: const EdgeInsets.all(AppTokens.spaceL),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusL),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withAlpha(60),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '启用流程',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppTokens.spaceL),
                        _buildStep(
                          context,
                          number: 1,
                          title: '系统指纹认证',
                          description:
                              '调用系统指纹进行身份验证，使用您已注册的指纹信息',
                        ),
                        const SizedBox(height: AppTokens.spaceM),
                        _buildStep(
                          context,
                          number: 2,
                          title: '验证主密码',
                          description: '输入主密码确认身份，用于派生加密密钥',
                        ),
                        const SizedBox(height: AppTokens.spaceM),
                        _buildStep(
                          context,
                          number: 3,
                          title: '启用成功',
                          description:
                              '之后可使用$biometricTypeName快速解锁保险库',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTokens.spaceXL),

                  // 密码输入
                  SecureTextField(
                    controller: _passwordController,
                    labelText: '主密码',
                    hintText: '请输入主密码用于派生加密密钥',
                    prefixIcon: Icons.lock_outline_rounded,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主密码';
                      }
                      return null;
                    },
                    onSubmitted: (_) => _enableBiometric(),
                  ),

                  const SizedBox(height: AppTokens.spaceXL),

                  // 启用按钮
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      gradient: authState.isLoading
                          ? null
                          : AppTokens.primaryGradient,
                      color: authState.isLoading
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : null,
                      boxShadow: authState.isLoading
                          ? null
                          : [
                              BoxShadow(
                                color:
                                    const Color(0xFF6366F1).withAlpha(100),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed:
                          authState.isLoading ? null : _enableBiometric,
                      icon: Icon(biometricIcon),
                      label: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('启用 $biometricTypeName'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.spaceM,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // 已启用卡片
                  Container(
                    padding: const EdgeInsets.all(AppTokens.spaceL),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF6366F1).withAlpha(30),
                          const Color(0xFF8B5CF6).withAlpha(15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusL),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withAlpha(30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF6366F1),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceM),
                        Expanded(
                          child: Text(
                            '$biometricTypeName 已启用，可用于快速解锁',
                            style: TextStyle(
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTokens.spaceXL),

                  OutlinedButton.icon(
                    onPressed: _disableBiometric,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('禁用生物识别'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error.withAlpha(120),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceM,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppTokens.spaceXL),

                // 错误提示
                if (authState.error != null)
                  Container(
                    padding: const EdgeInsets.all(AppTokens.spaceM),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTokens.radiusL),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppTokens.spaceS),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
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
            gradient: AppTokens.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withAlpha(60),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppTokens.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTokens.spaceXS),
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
