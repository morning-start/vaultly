import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/services/totp_service.dart';

class EntryDetailPage extends ConsumerStatefulWidget {
  final String entryId;

  const EntryDetailPage({super.key, required this.entryId});

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  VaultEntry? _entry;
  String? _totpCode;
  Timer? _totpTimer;
  bool _showPassword = false;
  bool _showCvv = false;
  bool _showIdNumber = false;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final vaultService = ref.read(vaultServiceProvider);
    final entry = vaultService.getEntry(widget.entryId);
    if (entry != null && mounted) {
      setState(() => _entry = entry);
      if (entry.type == EntryType.login && entry.totpSecretEncrypted != null) {
        _startTotpTimer();
      }
    }
  }

  void _startTotpTimer() {
    _updateTotp();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTotp();
    });
  }

  void _updateTotp() {
    if (_entry?.totpSecretEncrypted != null) {
      final totpService = TOTPService();
      final code = totpService.generateTOTP(_entry!.totpSecretEncrypted!);
      if (mounted) {
        setState(() => _totpCode = code);
      }
    }
  }

  Future<void> _copyToClipboard(String? text, String label) async {
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 已复制到剪贴板')),
      );
      Future.delayed(const Duration(seconds: 30), () {
        Clipboard.setData(const ClipboardData(text: ''));
      });
    }
  }

  Future<void> _deleteEntry() async {
    if (_entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${_entry!.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final vaultService = ref.read(vaultServiceProvider);
      await vaultService.deleteEntry(_entry!.uuid);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_entry == null) return;
    final vaultService = ref.read(vaultServiceProvider);
    await vaultService.toggleFavorite(_entry!.uuid);
    await _loadEntry();
  }

  @override
  Widget build(BuildContext context) {
    if (_entry == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final entry = _entry!;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          IconButton(
            icon: Icon(entry.isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _deleteEntry();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (entry.type == EntryType.login) ..._buildLoginFields(entry),
          if (entry.type == EntryType.bankCard) ..._buildBankCardFields(entry),
          if (entry.type == EntryType.secureNote) ..._buildSecureNoteFields(entry),
          if (entry.type == EntryType.identity) ..._buildIdentityFields(entry),
          const SizedBox(height: 16),
          if (entry.tags.isNotEmpty) ...[
            Text('标签', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: entry.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLoginFields(VaultEntry entry) {
    return [
      if (entry.usernameEncrypted != null && entry.usernameEncrypted!.isNotEmpty)
        _buildField('用户名', entry.usernameEncrypted!, Icons.person),
      if (entry.emailEncrypted != null && entry.emailEncrypted!.isNotEmpty)
        _buildField('邮箱', entry.emailEncrypted!, Icons.email),
      if (entry.passwordEncrypted != null && entry.passwordEncrypted!.isNotEmpty)
        _buildPasswordField('密码', entry.passwordEncrypted!, Icons.lock),
      if (entry.url != null && entry.url!.isNotEmpty)
        _buildUrlField('网址', entry.url!, Icons.link),
      if (_totpCode != null)
        _buildTotpField('验证码', _totpCode!, Icons.timer),
      if (entry.notesEncrypted != null && entry.notesEncrypted!.isNotEmpty)
        _buildField('备注', entry.notesEncrypted!, Icons.note),
    ];
  }

  List<Widget> _buildBankCardFields(VaultEntry entry) {
    return [
      if (entry.cardNumberEncrypted != null && entry.cardNumberEncrypted!.isNotEmpty)
        _buildPasswordField('卡号', entry.cardNumberEncrypted!, Icons.credit_card),
      if (entry.cardHolderName != null && entry.cardHolderName!.isNotEmpty)
        _buildField('持卡人', entry.cardHolderName!, Icons.person),
      if (entry.expiryMonth != null && entry.expiryYear != null)
        _buildField(
          '有效期',
          '${entry.expiryMonth.toString().padLeft(2, '0')}/${entry.expiryYear}',
          Icons.calendar_today,
        ),
      if (entry.cvvEncrypted != null && entry.cvvEncrypted!.isNotEmpty)
        _buildCvvField('CVV', entry.cvvEncrypted!, Icons.security),
      if (entry.bankName != null && entry.bankName!.isNotEmpty)
        _buildField('银行', entry.bankName!, Icons.account_balance),
    ];
  }

  List<Widget> _buildSecureNoteFields(VaultEntry entry) {
    return [
      if (entry.noteContentEncrypted != null && entry.noteContentEncrypted!.isNotEmpty)
        _buildField('内容', entry.noteContentEncrypted!, Icons.note),
    ];
  }

  List<Widget> _buildIdentityFields(VaultEntry entry) {
    return [
      if (entry.firstName != null || entry.lastName != null)
        _buildField('姓名', '${entry.firstName ?? ''} ${entry.lastName ?? ''}', Icons.person),
      if (entry.idNumberEncrypted != null && entry.idNumberEncrypted!.isNotEmpty)
        _buildIdNumberField('证件号', entry.idNumberEncrypted!, Icons.badge),
      if (entry.phoneEncrypted != null && entry.phoneEncrypted!.isNotEmpty)
        _buildField('电话', entry.phoneEncrypted!, Icons.phone),
      if (entry.emailEncrypted != null && entry.emailEncrypted!.isNotEmpty)
        _buildField('邮箱', entry.emailEncrypted!, Icons.email),
      if (entry.addressEncrypted != null && entry.addressEncrypted!.isNotEmpty)
        _buildField('地址', entry.addressEncrypted!, Icons.location_on),
    ];
  }

  Widget _buildField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => _copyToClipboard(value, label),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(_showPassword ? value : '••••••••'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(value, label),
            ),
            IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() => _showPassword = !_showPassword);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCvvField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(_showCvv ? value : '•••'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_showCvv ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() => _showCvv = !_showCvv);
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(value, label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdNumberField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(_showIdNumber ? value : '••••••••••••'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_showIdNumber ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() => _showIdNumber = !_showIdNumber);
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(value, label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotpField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: Text(
          '${value.substring(0, 3)} ${value.substring(3)}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => _copyToClipboard(value, label),
        ),
      ),
    );
  }

  Widget _buildUrlField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () async {
                final uri = Uri.parse(value);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(value, label),
            ),
          ],
        ),
      ),
    );
  }
}
