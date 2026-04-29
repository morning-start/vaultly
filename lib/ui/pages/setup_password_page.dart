import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/password_generator.dart';
import '../../core/utils/password_policy.dart';
import '../widgets/secure_text_field.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/password_suggestions_widget.dart';

class SetupPasswordPage extends ConsumerStatefulWidget {
  const SetupPasswordPage({super.key});

  @override
  ConsumerState<SetupPasswordPage> createState() => _SetupPasswordPageState();
}

class _SetupPasswordPageState extends ConsumerState<SetupPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _passwordStrength = PasswordGenerator.calculateStrength(password);
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    
    final result = PasswordPolicy.validate(value);
    if (!result.isValid) {
      return result.firstError;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请再次输入密码';
    }
    if (value != _passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  Future<void> _setupPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    final success = await ref.read(authNotifierProvider.notifier).setupPassword(password);

    if (success && mounted) {
      context.go('/unlock');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建保险库'),
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
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  '创建主密码',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '请设置一个强密码来保护您的保险库',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SecureTextField(
                  controller: _passwordController,
                  labelText: '主密码',
                  hintText: '请输入主密码',
                  prefixIcon: Icons.lock,
                  validator: _validatePassword,
                  onChanged: (_) => _updatePasswordStrength(),
                ),
                const SizedBox(height: 8),
                PasswordStrengthIndicator(strength: _passwordStrength),
                const SizedBox(height: 16),
                SecureTextField(
                  controller: _confirmController,
                  labelText: '确认密码',
                  hintText: '请再次输入密码',
                  prefixIcon: Icons.lock_outline,
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 16),
                PasswordSuggestionsWidget.policy(),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _setupPassword,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('创建保险库'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
