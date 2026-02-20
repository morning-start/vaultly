import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/webdav_service.dart';

/// WebDAV 配置页面
///
/// 配置 WebDAV 服务器连接信息，支持测试连接和手动同步
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

  final WebDAVService _webDAVService = WebDAVService();

  bool _isLoading = false;
  bool _isConfigured = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    final config = await _webDAVService.getConfig();
    final isConfigured = await _webDAVService.isConfigured();

    if (config != null && mounted) {
      setState(() {
        _urlController.text = config.url;
        _usernameController.text = config.username;
        _passwordController.text = config.password;
        _isConfigured = isConfigured;
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    // 先测试连接
    final connected = await _webDAVService.testConnection(config);

    if (!mounted) return;

    if (!connected) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('连接失败，请检查配置信息'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 保存配置
    await _webDAVService.saveConfig(config);

    if (!mounted) return;

    setState(() {
      _isConfigured = true;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除 WebDAV 配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _webDAVService.clearConfig();
      if (mounted) {
        setState(() {
          _urlController.clear();
          _usernameController.clear();
          _passwordController.clear();
          _isConfigured = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已清除')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    final connected = await _webDAVService.testConnection(config);

    if (!mounted) return;

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected ? '连接成功' : '连接失败'),
        backgroundColor: connected ? Colors.green : Colors.red,
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 同步'),
        actions: [
          if (_isConfigured)
            TextButton(
              onPressed: _clearConfig,
              child: const Text('清除配置'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 状态卡片
                    _buildStatusCard(),
                    const SizedBox(height: 24),

                    // 配置表单
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '服务器配置',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                labelText: '服务器地址 *',
                                hintText: 'https://dav.example.com',
                                prefixIcon: Icon(Icons.cloud),
                              ),
                              keyboardType: TextInputType.url,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入服务器地址';
                                }
                                if (!value.startsWith('http')) {
                                  return '地址必须以 http:// 或 https:// 开头';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: '用户名 *',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入用户名';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: '密码 *',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () {
                                    setState(() =>
                                        _obscurePassword = !_obscurePassword);
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入密码';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testConnection,
                            icon: const Icon(Icons.network_check),
                            label: const Text('测试连接'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveConfig,
                            icon: const Icon(Icons.save),
                            label: const Text('保存配置'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 说明
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '使用说明',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '1. 支持坚果云、Nextcloud、OwnCloud 等 WebDAV 服务\n'
                              '2. 数据将以加密形式存储在服务器上\n'
                              '3. 建议在保险库页面手动触发同步',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isConfigured
                    ? Colors.green.withAlpha(26)
                    : Colors.orange.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isConfigured ? Icons.cloud_done : Icons.cloud_off,
                color: _isConfigured ? Colors.green : Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isConfigured ? '已配置' : '未配置',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConfigured
                        ? 'WebDAV 同步已启用'
                        : '请配置 WebDAV 服务器信息',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
