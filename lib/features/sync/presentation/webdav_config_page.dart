import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/sync_models.dart';
import 'sync_providers.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/secure_text_field.dart';
import '../../../../ui/theme/tokens.dart';
import '../../../../ui/theme/vaultly_colors.dart';

/// WebDAV 连接配置页
///
/// 只负责服务器连接信息（地址 / 账号 / 应用密码）与连接测试。
/// 加密、压缩、合并或覆盖等运行期选项在每次上传/下载时单独选择，
/// 不再固化在配置里。
class WebDAVConfigPage extends ConsumerStatefulWidget {
  const WebDAVConfigPage({super.key});

  @override
  ConsumerState<WebDAVConfigPage> createState() => _WebDAVConfigPageState();
}

class _WebDAVConfigPageState extends ConsumerState<WebDAVConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    final webDAVService = ref.read(webDAVServiceProvider);
    final config = await webDAVService.getConfig();

    if (config != null && mounted) {
      setState(() {
        _urlController.text = config.serverUrl;
        _usernameController.text = config.username;
        _passwordController.text = config.password ?? '';
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  SyncConfig _buildConfig() {
    return SyncConfig(
      id: 'webdav_default',
      serverUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final webDAVService = ref.read(webDAVServiceProvider);
    final config = _buildConfig();
    final result = await webDAVService.testConnection(config);

    if (!mounted) return;

    if (!result.success) {
      setState(() => _isLoading = false);
      _toast('连接失败：${result.errorMessage ?? '请检查配置信息'}');
      return;
    }

    await webDAVService.saveConfig(config);
    if (!mounted) return;

    await ref.read(webDAVConfigProvider.notifier).refresh();
    if (!mounted) return;

    setState(() => _isLoading = false);
    _toast('连接已保存');
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await ref
        .read(webDAVServiceProvider)
        .testConnection(_buildConfig());

    if (!mounted) return;
    setState(() => _isLoading = false);

    _toast(result.success ? '连接成功' : '连接失败：${result.errorMessage ?? '未知错误'}');
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '清除连接配置',
        content: '清除后需要重新填写服务器信息，云端已有的备份不会被删除。',
        confirmLabel: '清除',
        isDangerous: true,
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(webDAVServiceProvider).clearConfig();
    if (!mounted) return;

    await ref.read(webDAVConfigProvider.notifier).refresh();
    if (!mounted) return;

    setState(() {
      _urlController.clear();
      _usernameController.clear();
      _passwordController.clear();
    });
    _toast('连接配置已清除');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(webDAVConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.bg,
      appBar: AppBar(
        title: const Text('WebDAV 连接'),
        actions: [
          if (configState.isConfigured)
            IconButton(
              onPressed: _clearConfig,
              icon: const Icon(Icons.link_off_rounded, size: 22),
              tooltip: '清除连接',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildStatusCard(configState.isConfigured, colorScheme),
                  const _SectionLabel('服务器'),
                  _buildConnectionCard(colorScheme),
                  const _SectionLabel('运行期选项'),
                  _buildRuntimeNoteCard(colorScheme),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testConnection,
                          icon: const Icon(
                            Icons.network_check_rounded,
                            size: 18,
                          ),
                          label: const Text('测试连接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saveConfig,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('保存连接'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '备份固定保存在 /vaultly/ 目录下，\n服务器上只保存你每次选择的格式。',
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
    );
  }

  Widget _buildStatusCard(bool isConfigured, ColorScheme colorScheme) {
    final color = isConfigured ? colorScheme.accent : colorScheme.textMuted;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      child: Row(
        children: [
          Icon(
            isConfigured ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 22,
            color: color,
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConfigured ? '连接已保存' : '尚未连接',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  isConfigured ? '可以前往同步页上传或恢复备份' : '填写服务器信息并保存后即可同步',
                  style: TextStyle(fontSize: 12, color: colorScheme.textMuted),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel('服务器地址'),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://dav.example.com',
              prefixIcon: Icon(Icons.cloud_outlined, size: 20),
            ),
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入服务器地址';
              }
              final uri = Uri.tryParse(value.trim());
              if (uri == null ||
                  !(uri.scheme == 'http' || uri.scheme == 'https')) {
                return '地址必须以 http:// 或 https:// 开头';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          _FieldLabel('用户名'),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              hintText: 'WebDAV 账号',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入用户名';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          _FieldLabel('应用密码'),
          SecureTextField(
            controller: _passwordController,
            hintText: 'WebDAV 应用密码 / 授权码',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入应用密码';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeNoteCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _noteRow(
            colorScheme,
            Icons.merge_rounded,
            '处理模式',
            '每次上传 / 恢复时可选择兼容（合并）或覆盖',
          ),
          const SizedBox(height: 12),
          _noteRow(
            colorScheme,
            Icons.shield_outlined,
            '数据格式',
            '每次可选择加密（AES-256-GCM）或明文 JSON',
          ),
          const SizedBox(height: 12),
          _noteRow(
            colorScheme,
            Icons.compress_rounded,
            '传输压缩',
            '每次可选择是否启用 GZIP 压缩',
          ),
        ],
      ),
    );
  }

  Widget _noteRow(
    ColorScheme colorScheme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: AppTokens.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: colorScheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: Theme.of(context).colorScheme.textMuted,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.textMuted,
        ),
      ),
    );
  }
}
