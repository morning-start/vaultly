import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_providers.dart';
import '../../tools/password_generator.dart';
import '../../tools/password_policy.dart';
import '../../../shared/widgets/secure_text_field.dart';
import '../../../shared/widgets/vault_dial.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';

/// 创建主密码页（原型 setup.html）
///
/// 结构：表盘徽记 → 标题与说明 → 主密码（强度条）→ 规则清单卡片
/// → 无法找回警告卡片 → 确认主密码 → 创建按钮 → 页脚加密说明。
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
    final success = await ref
        .read(authNotifierProvider.notifier)
        .setupPassword(password);

    if (success && mounted) {
      context.go('/unlock');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final password = _passwordController.text;

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
                      colorScheme.primary.withAlpha(36),
                      colorScheme.primary.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: VaultDial(size: 96)),
                    const SizedBox(height: 22),
                    Text(
                      '创建你的保险库',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '主密码是打开保险库的唯一钥匙，\n之后的所有数据都由它加密。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.textMuted,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _label('主密码'),
                    SecureTextField(
                      controller: _passwordController,
                      hintText: '输入主密码',
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: _validatePassword,
                    ),
                    if (_passwordStrength > 0) _buildStrengthRow(colorScheme),
                    const SizedBox(height: 14),
                    _buildCheckList(password, colorScheme),
                    const SizedBox(height: 14),
                    _buildWarnCard(context, colorScheme),
                    const SizedBox(height: 14),
                    _label('确认主密码'),
                    SecureTextField(
                      controller: _confirmController,
                      hintText: '再次输入主密码',
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: authState.isLoading ? null : _setupPassword,
                      child: authState.isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Text('创建保险库'),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Vaultly · AES-256-GCM · 纯本地加密',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.8,
                        color: colorScheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: Theme.of(context).colorScheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildStrengthRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.spaceS),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (_passwordStrength / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: colorScheme.surfaceTrack,
                color: colorScheme.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${PasswordPolicy.getStrengthLabel(_passwordStrength)} · '
            '$_passwordStrength/100',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckList(String password, ColorScheme colorScheme) {
    final checks = <(bool, String)>[
      (password.length >= PasswordPolicy.recommendedLength, '至少 12 个字符'),
      (_hasUpperLowerDigit(password), '包含大小写字母与数字'),
      (_hasSymbol(password), '包含符号'),
      (_notCommon(password), '未出现在常见泄露库中'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      child: Column(
        children: [
          for (final (passed, text) in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: passed ? colorScheme.accent : colorScheme.textFaint,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        color: passed
                            ? colorScheme.onSurface
                            : colorScheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarnCard(BuildContext context, ColorScheme colorScheme) {
    final warning = colorScheme.isDark
        ? AppTokens.warningDark
        : AppTokens.warningLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: warning.withAlpha(23),
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: warning.withAlpha(82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 19, color: warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '主密码无法找回',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'Vaultly 不存储你的主密码，也没有任何后门。请务必牢记，'
                  '或把恢复密钥保存在安全的地方。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.65,
                    color: colorScheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasUpperLowerDigit(String password) {
    return password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  bool _hasSymbol(String password) {
    return password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'));
  }

  bool _notCommon(String password) {
    if (password.isEmpty) return false;
    final failures = PasswordPolicy.validate(password).failures;
    return !failures.any((f) => f.contains('常见'));
  }
}
