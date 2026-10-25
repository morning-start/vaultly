import 'package:flutter/material.dart';
import '../../../features/tools/presentation/password_generator_panel.dart';
import '../../../ui/theme/tokens.dart';

/// 工具页
///
/// 密码生成器（页面化）+ 未来更多安全小工具。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        children: const [
          PasswordGeneratorPanel(),
        ],
      ),
    );
  }
}
