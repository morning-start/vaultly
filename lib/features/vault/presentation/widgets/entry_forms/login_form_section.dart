import 'package:flutter/material.dart';
import '../../../../../shared/widgets/secure_text_field.dart';
import '../../../../../ui/theme/tokens.dart';
import '../../../../tools/presentation/password_generator_dialog.dart';
import '../../../../tools/presentation/password_strength_indicator.dart';
import 'entry_form_controllers.dart';

/// 登录凭证表单分区。
///
/// 密码强度监听与生成器回调由宿主页注入。
class LoginFormSection extends StatelessWidget {
  final EntryFormControllers controllers;
  final int passwordStrength;
  final VoidCallback onPasswordChanged;

  const LoginFormSection({
    super.key,
    required this.controllers,
    required this.passwordStrength,
    required this.onPasswordChanged,
  });

  Future<void> _showPasswordGenerator(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => PasswordGeneratorDialog(
        initialPassword: controllers.password.text.isNotEmpty
            ? controllers.password.text
            : null,
      ),
    );

    if (password != null) {
      controllers.password.text = password;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controllers.username,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '用户名或账号',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: controllers.email,
          decoration: const InputDecoration(
            labelText: '邮箱',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppTokens.spaceL),
        SecureTextField(
          controller: controllers.password,
          labelText: '密码',
          prefixIcon: Icons.lock,
          onChanged: (_) => onPasswordChanged(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _showPasswordGenerator(context),
            tooltip: '生成密码',
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        PasswordStrengthIndicator(strength: passwordStrength),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: controllers.url,
          decoration: const InputDecoration(
            labelText: '网站 URL',
            hintText: 'https://example.com',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: controllers.totpSecret,
          decoration: const InputDecoration(
            labelText: 'TOTP 密钥',
            hintText: '用于双因素认证',
            prefixIcon: Icon(Icons.timer),
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: controllers.notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '备注',
            prefixIcon: Icon(Icons.note),
          ),
        ),
      ],
    );
  }
}
