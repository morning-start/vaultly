import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/services/totp_service.dart';

class EntryDetailPage extends ConsumerStatefulWidget {
  final VaultEntry entry;

  const EntryDetailPage({super.key, required this.entry});

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  late VaultEntry _entry;
  String? _totpCode;
  Timer? _totpTimer;
  bool _showCvv = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadEntry();
    if (_entry is LoginEntry && (_entry as LoginEntry).totpSecret != null) {
      _startTotpTimer();
    }
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final vaultService = ref.read(vaultServiceProvider);
    final entry = vaultService.getEntry(_entry.id);
    if (entry != null && mounted) {
      setState(() => _entry = entry);
    }
  }

  void _startTotpTimer() {
    _updateTotp();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTotp();
    });
  }

  void _updateTotp() {
    if (_entry is LoginEntry) {
      final loginEntry = _entry as LoginEntry;
      if (loginEntry.totpSecret != null && loginEntry.totpSecret!.isNotEmpty) {
        final totpService = TOTPService();
        final code = totpService.generateTOTP(loginEntry.totpSecret!);
        if (mounted) {
          setState(() => _totpCode = code);
        }
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${_entry.title}" 吗？'),
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
      await vaultService.deleteEntry(_entry.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final vaultService = ref.read(vaultServiceProvider);
    await vaultService.toggleFavorite(_entry.id);
    await _loadEntry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.title),
        actions: [
          IconButton(
            icon: Icon(_entry.isFavorite ? Icons.star : Icons.star_border),
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
          if (_entry is LoginEntry) ..._buildLoginFields(_entry as LoginEntry),
          if (_entry is BankCardEntry) ..._buildBankCardFields(_entry as BankCardEntry),
          if (_entry is SecureNoteEntry) ..._buildSecureNoteFields(_entry as SecureNoteEntry),
          if (_entry is IdentityEntry) ..._buildIdentityFields(_entry as IdentityEntry),
          const SizedBox(height: 16),
          if (_entry.tags.isNotEmpty) ...[
            Text('标签', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _entry.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLoginFields(LoginEntry entry) {
    return [
      if (entry.username != null && entry.username!.isNotEmpty)
        _buildField('用户名', entry.username!, Icons.person),
      if (entry.email != null && entry.email!.isNotEmpty)
        _buildField('邮箱', entry.email!, Icons.email),
      if (entry.password != null && entry.password!.isNotEmpty)
        _buildPasswordField('密码', entry.password!, Icons.lock),
      if (entry.url != null && entry.url!.isNotEmpty)
        _buildUrlField('网址', entry.url!, Icons.link),
      if (_totpCode != null)
        _buildTotpField('验证码', _totpCode!, Icons.timer),
      if (entry.notes != null && entry.notes!.isNotEmpty)
        _buildField('备注', entry.notes!, Icons.note),
    ];
  }

  List<Widget> _buildBankCardFields(BankCardEntry entry) {
    return [
      if (entry.cardNumber != null && entry.cardNumber!.isNotEmpty)
        _buildPasswordField('卡号', entry.cardNumber!, Icons.credit_card),
      if (entry.cardHolderName != null && entry.cardHolderName!.isNotEmpty)
        _buildField('持卡人', entry.cardHolderName!, Icons.person),
      if (entry.expiryMonth != null && entry.expiryYear != null)
        _buildField(
          '有效期',
          '${entry.expiryMonth.toString().padLeft(2, '0')}/${entry.expiryYear}',
          Icons.calendar_today,
        ),
      if (entry.cvv != null && entry.cvv!.isNotEmpty)
        _buildCvvField('CVV', entry.cvv!, Icons.security),
      if (entry.bankName != null && entry.bankName!.isNotEmpty)
        _buildField('银行', entry.bankName!, Icons.account_balance),
    ];
  }

  List<Widget> _buildSecureNoteFields(SecureNoteEntry entry) {
    return [
      if (entry.content != null && entry.content!.isNotEmpty)
        _buildField('内容', entry.content!, Icons.note),
    ];
  }

  List<Widget> _buildIdentityFields(IdentityEntry entry) {
    return [
      if (entry.firstName != null || entry.lastName != null)
        _buildField('姓名', '${entry.firstName ?? ''} ${entry.lastName ?? ''}', Icons.person),
      if (entry.idNumber != null && entry.idNumber!.isNotEmpty)
        _buildPasswordField('证件号', entry.idNumber!, Icons.badge),
      if (entry.phone != null && entry.phone!.isNotEmpty)
        _buildField('电话', entry.phone!, Icons.phone),
      if (entry.email != null && entry.email!.isNotEmpty)
        _buildField('邮箱', entry.email!, Icons.email),
      if (entry.address != null && entry.address!.isNotEmpty)
        _buildField('地址', entry.address!, Icons.location_on),
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
        subtitle: Text(label == '验证码' ? value : '••••••••'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != '验证码')
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(value, label),
              ),
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                setState(() {});
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
