import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/services/clipboard_service.dart';
import '../../core/services/totp_service.dart';
import 'add_entry_page.dart';

/// 条目详情页面
///
/// 显示条目详细信息，支持复制、编辑、删除操作
class EntryDetailPage extends ConsumerStatefulWidget {
  final String entryId;

  const EntryDetailPage({
    super.key,
    required this.entryId,
  });

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  VaultEntry? _entry;
  String? _totpCode;
  int? _totpRemainingSeconds;
  Timer? _totpTimer;

  // 显示状态
  final Map<String, bool> _showSensitive = {};

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
      final remaining = totpService.getRemainingSeconds();
      
      if (mounted) {
        setState(() {
          _totpCode = code;
          _totpRemainingSeconds = remaining;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String? text, String label) async {
    if (text == null || text.isEmpty) return;
    
    await ClipboardService.copy(text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 已复制到剪贴板（30秒后自动清除）')),
      );
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final vaultService = ref.read(vaultServiceProvider);
      await vaultService.deleteEntry(_entry!.uuid);
      if (mounted) {
        context.pop();
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_entry == null) return;
    final vaultService = ref.read(vaultServiceProvider);
    await vaultService.toggleFavorite(_entry!.uuid);
    await _loadEntry();
  }

  Future<void> _editEntry() async {
    if (_entry == null) return;
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEntryPage(entryId: _entry!.uuid),
      ),
    );
    
    // 刷新条目数据
    await _loadEntry();
  }

  bool _isSensitiveVisible(String fieldKey) {
    return _showSensitive[fieldKey] ?? false;
  }

  void _toggleSensitiveVisibility(String fieldKey) {
    setState(() {
      _showSensitive[fieldKey] = !(_showSensitive[fieldKey] ?? false);
    });
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
            tooltip: entry.isFavorite ? '取消收藏' : '收藏',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editEntry,
            tooltip: '编辑',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
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
          // 条目类型标签
          _buildTypeHeader(entry),
          const SizedBox(height: 16),

          // 类型特定字段
          ..._buildTypeSpecificFields(entry),

          // 标签
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTagsSection(entry),
          ],

          // 元信息
          const SizedBox(height: 24),
          _buildMetadataSection(entry),
        ],
      ),
    );
  }

  Widget _buildTypeHeader(VaultEntry entry) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(entry.type),
          child: Icon(
            _getTypeIcon(entry.type),
            color: Colors.white,
          ),
        ),
        title: Text(_getTypeName(entry.type)),
        subtitle: Text('创建于 ${_formatDate(entry.createdAt)}'),
      ),
    );
  }

  List<Widget> _buildTypeSpecificFields(VaultEntry entry) {
    switch (entry.type) {
      case EntryType.login:
        return _buildLoginFields(entry);
      case EntryType.bankCard:
        return _buildBankCardFields(entry);
      case EntryType.secureNote:
        return _buildSecureNoteFields(entry);
      case EntryType.identity:
        return _buildIdentityFields(entry);
    }
  }

  List<Widget> _buildLoginFields(VaultEntry entry) {
    return [
      if (entry.usernameEncrypted != null && entry.usernameEncrypted!.isNotEmpty)
        _buildCopyableField(
          '用户名',
          entry.usernameEncrypted!,
          Icons.person,
          isSensitive: false,
        ),
      if (entry.emailEncrypted != null && entry.emailEncrypted!.isNotEmpty)
        _buildCopyableField(
          '邮箱',
          entry.emailEncrypted!,
          Icons.email,
          isSensitive: false,
        ),
      if (entry.passwordEncrypted != null && entry.passwordEncrypted!.isNotEmpty)
        _buildCopyableField(
          '密码',
          entry.passwordEncrypted!,
          Icons.lock,
          isSensitive: true,
        ),
      if (entry.url != null && entry.url!.isNotEmpty)
        _buildUrlField('网站', entry.url!, Icons.link),
      if (_totpCode != null)
        _buildTotpField('验证码', _totpCode!, _totpRemainingSeconds ?? 30),
      if (entry.notesEncrypted != null && entry.notesEncrypted!.isNotEmpty)
        _buildNoteField('备注', entry.notesEncrypted!),
    ];
  }

  List<Widget> _buildBankCardFields(VaultEntry entry) {
    return [
      if (entry.cardNumberEncrypted != null && entry.cardNumberEncrypted!.isNotEmpty)
        _buildCopyableField(
          '卡号',
          entry.cardNumberEncrypted!,
          Icons.credit_card,
          isSensitive: true,
        ),
      if (entry.cardHolderName != null && entry.cardHolderName!.isNotEmpty)
        _buildDisplayField('持卡人', entry.cardHolderName!, Icons.person),
      if (entry.expiryMonth != null && entry.expiryYear != null)
        _buildDisplayField(
          '有效期',
          '${entry.expiryMonth.toString().padLeft(2, '0')}/${entry.expiryYear}',
          Icons.calendar_today,
        ),
      if (entry.cvvEncrypted != null && entry.cvvEncrypted!.isNotEmpty)
        _buildCopyableField(
          'CVV',
          entry.cvvEncrypted!,
          Icons.security,
          isSensitive: true,
        ),
      if (entry.bankName != null && entry.bankName!.isNotEmpty)
        _buildDisplayField('银行', entry.bankName!, Icons.account_balance),
      if (entry.cardType != null)
        _buildDisplayField('卡类型', _getCardTypeName(entry.cardType!), Icons.payment),
    ];
  }

  List<Widget> _buildSecureNoteFields(VaultEntry entry) {
    return [
      if (entry.isMarkdown)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.markdown, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Markdown 内容',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const Divider(),
                Text(entry.noteContentEncrypted ?? ''),
              ],
            ),
          ),
        )
      else
        _buildNoteField('内容', entry.noteContentEncrypted ?? ''),
    ];
  }

  List<Widget> _buildIdentityFields(VaultEntry entry) {
    final nameParts = [
      entry.lastName,
      entry.middleName,
      entry.firstName,
    ].where((p) => p != null && p.isNotEmpty).join(' ');

    return [
      if (nameParts.isNotEmpty)
        _buildDisplayField('姓名', nameParts, Icons.person),
      if (entry.birthDate != null)
        _buildDisplayField('出生日期', _formatDate(entry.birthDate!), Icons.cake),
      if (entry.idNumberEncrypted != null && entry.idNumberEncrypted!.isNotEmpty)
        _buildCopyableField(
          '证件号码',
          entry.idNumberEncrypted!,
          Icons.badge,
          isSensitive: true,
        ),
      if (entry.phoneEncrypted != null && entry.phoneEncrypted!.isNotEmpty)
        _buildCopyableField(
          '电话',
          entry.phoneEncrypted!,
          Icons.phone,
          isSensitive: false,
        ),
      if (entry.emailEncrypted != null && entry.emailEncrypted!.isNotEmpty)
        _buildCopyableField(
          '邮箱',
          entry.emailEncrypted!,
          Icons.email,
          isSensitive: false,
        ),
      if (entry.addressEncrypted != null && entry.addressEncrypted!.isNotEmpty)
        _buildCopyableField(
          '地址',
          entry.addressEncrypted!,
          Icons.location_on,
          isSensitive: false,
        ),
    ];
  }

  Widget _buildCopyableField(
    String label,
    String value,
    IconData icon, {
    required bool isSensitive,
  }) {
    final fieldKey = '${label}_$value';
    final showValue = !isSensitive || _isSensitiveVisible(fieldKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          showValue ? value : '••••••••',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSensitive)
              IconButton(
                icon: Icon(_isSensitiveVisible(fieldKey) ? Icons.visibility_off : Icons.visibility),
                onPressed: () => _toggleSensitiveVisibility(fieldKey),
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

  Widget _buildDisplayField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }

  Widget _buildUrlField(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () async {
                final uri = Uri.parse(value);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(value, label),
            ),
          ],
        ),
        onTap: () async {
          final uri = Uri.parse(value);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  Widget _buildTotpField(String label, String code, int remainingSeconds) {
    final progress = remainingSeconds / 30;
    final color = progress < 0.3 ? Colors.red : Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surface,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          ListTile(
            leading: Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
            title: Text(label),
            subtitle: Text(
              '${code.substring(0, 3)} ${code.substring(3)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: Text(
              '${remainingSeconds}s',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _copyToClipboard(code, label),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(value),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(VaultEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('标签', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entry.tags.map((tag) => Chip(
            label: Text(tag),
            avatar: const Icon(Icons.tag, size: 16),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(VaultEntry entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('元信息', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildMetadataRow('创建时间', _formatDateTime(entry.createdAt)),
            _buildMetadataRow('更新时间', _formatDateTime(entry.updatedAt)),
            _buildMetadataRow('UUID', entry.uuid.substring(0, 8) + '...'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  IconData _getTypeIcon(EntryType type) {
    return switch (type) {
      EntryType.login => Icons.login,
      EntryType.bankCard => Icons.credit_card,
      EntryType.secureNote => Icons.note,
      EntryType.identity => Icons.person,
    };
  }

  Color _getTypeColor(EntryType type) {
    return switch (type) {
      EntryType.login => Colors.blue,
      EntryType.bankCard => Colors.green,
      EntryType.secureNote => Colors.orange,
      EntryType.identity => Colors.purple,
    };
  }

  String _getTypeName(EntryType type) {
    return switch (type) {
      EntryType.login => '登录凭证',
      EntryType.bankCard => '银行卡',
      EntryType.secureNote => '安全笔记',
      EntryType.identity => '身份信息',
    };
  }

  String _getCardTypeName(CardType type) {
    return switch (type) {
      CardType.visa => 'Visa',
      CardType.mastercard => 'Mastercard',
      CardType.amex => 'American Express',
      CardType.unionPay => 'UnionPay',
      CardType.other => '其他',
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
