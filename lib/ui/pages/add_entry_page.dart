import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/utils/password_generator.dart';

class AddEntryPage extends ConsumerStatefulWidget {
  final String? entryType;
  final String? entryId;

  const AddEntryPage({
    super.key,
    this.entryType,
    this.entryId,
  });

  @override
  ConsumerState<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends ConsumerState<AddEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late EntryType _selectedType;

  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _obscurePassword = true;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _selectedType = _parseEntryType(widget.entryType);
    _passwordController.addListener(_updatePasswordStrength);
  }

  EntryType _parseEntryType(String? type) {
    if (type == null) return EntryType.login;
    return EntryType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => EntryType.login,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength = PasswordGenerator.calculateStrength(_passwordController.text);
    });
  }

  void _generatePassword() {
    final password = PasswordGenerator.generate(
      length: 16,
      includeUppercase: true,
      includeLowercase: true,
      includeNumbers: true,
      includeSymbols: true,
    );
    _passwordController.text = password;
    setState(() => _obscurePassword = false);
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final vaultService = ref.read(vaultServiceProvider);

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final entry = VaultEntry(
      title: _titleController.text,
      type: _selectedType,
      tags: tags,
    );

    // 设置加密字段
    if (_usernameController.text.isNotEmpty) {
      entry.usernameEncrypted = _usernameController.text;
    }
    if (_emailController.text.isNotEmpty) {
      entry.emailEncrypted = _emailController.text;
    }
    if (_passwordController.text.isNotEmpty) {
      entry.passwordEncrypted = _passwordController.text;
    }
    if (_urlController.text.isNotEmpty) {
      entry.url = _urlController.text;
    }
    if (_notesController.text.isNotEmpty) {
      entry.notesEncrypted = _notesController.text;
    }

    await vaultService.addEntry(entry);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('条目添加成功')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entryId != null ? '编辑条目' : '添加条目'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<EntryType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: '条目类型',
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: EntryType.login, child: Text('登录凭证')),
                DropdownMenuItem(value: EntryType.bankCard, child: Text('银行卡')),
                DropdownMenuItem(value: EntryType.secureNote, child: Text('安全笔记')),
                DropdownMenuItem(value: EntryType.identity, child: Text('身份信息')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '例如：Google 账号',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入标题';
                }
                return null;
              },
            ),
            if (_selectedType == EntryType.login) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '用户名或邮箱',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: _generatePassword,
                        tooltip: '生成密码',
                      ),
                    ],
                  ),
                ),
              ),
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _passwordStrength / 100,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '网站 URL',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注',
                  prefixIcon: Icon(Icons.note),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '用逗号分隔多个标签',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveEntry,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
