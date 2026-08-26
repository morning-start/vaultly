import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/vault_entry.dart';
import 'vault_providers.dart';
import '../../../features/tools/clipboard_service.dart';
import '../../../features/tools/totp_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../ui/theme/tokens.dart';
import 'widgets/entry_type_helper.dart';

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
    final entry = await vaultService.getEntry(widget.entryId);
    if (entry != null && mounted) {
      setState(() => _entry = entry);
      if (entry is LoginEntry && entry.totpSecret != null) {
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
    if (_entry is LoginEntry) {
      final loginEntry = _entry as LoginEntry;
      if (loginEntry.totpSecret != null) {
        final totpService = TOTPService();
        final code = totpService.generateTOTP(loginEntry.totpSecret!);
        final remaining = totpService.getRemainingSeconds();

        if (mounted) {
          setState(() {
            _totpCode = code;
            _totpRemainingSeconds = remaining;
          });
        }
      }
    }
  }

  Future<void> _copyToClipboard(String? text, String label) async {
    if (text == null || text.isEmpty) return;

    await ClipboardService.copy(text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
      );
    }
  }

  Future<void> _deleteEntry() async {
    if (_entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '确认删除',
        content: '确定要删除 "${_entry!.title}" 吗？',
        confirmLabel: '删除',
        isDangerous: true,
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

    await context.push('/entry/${_entry!.uuid}/edit');

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 现代渐变 Hero AppBar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  entry.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                ),
                onPressed: _toggleFavorite,
                tooltip: entry.isFavorite ? '取消收藏' : '收藏',
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: _editEntry,
                tooltip: '编辑',
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_rounded,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppTokens.spaceS),
                        Text(
                          '删除',
                          style: TextStyle(color: colorScheme.error),
                        ),
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
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                entry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              background: _buildHeroBackground(entry),
            ),
          ),
          // 内容区域
          SliverPadding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 类型信息卡片
                _buildTypeCard(entry),
                const SizedBox(height: AppTokens.spaceL),
                // 动态字段区域
                ..._buildTypeSpecificFields(entry),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.spaceL),
                  _buildTagsSection(entry),
                ],
                const SizedBox(height: AppTokens.spaceXL),
                _buildMetadataSection(entry),
                const SizedBox(height: AppTokens.spaceXXL),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBackground(VaultEntry entry) {
    final typeColor = EntryTypeHelper.getColor(entry.type);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withAlpha(60),
            typeColor.withAlpha(20),
            colorScheme.surface,
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            0,
            AppTokens.spaceL,
            AppTokens.spaceXL,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [typeColor, typeColor.withAlpha(180)],
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusL),
                  boxShadow: AppTokens.cardShadow(typeColor, opacity: 0.15),
                ),
                child: Icon(
                  EntryTypeHelper.getIcon(entry.type),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTokens.spaceM),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    EntryTypeHelper.getName(entry.type),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '创建于 ${_formatDate(entry.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(VaultEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EntryTypeHelper.getColor(entry.type),
                  EntryTypeHelper.getColor(entry.type).withAlpha(100),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EntryTypeHelper.getName(entry.type),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  entry.tags.isNotEmpty
                      ? entry.tags.take(3).join(' · ')
                      : '无标签',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTypeSpecificFields(VaultEntry entry) {
    switch (entry.type) {
      case EntryType.login:
        return entry is LoginEntry ? _buildLoginFields(entry) : [];
      case EntryType.bankCard:
        return entry is BankCardEntry ? _buildBankCardFields(entry) : [];
      case EntryType.secureNote:
        return entry is SecureNoteEntry ? _buildSecureNoteFields(entry) : [];
      case EntryType.identity:
        return entry is IdentityEntry ? _buildIdentityFields(entry) : [];
      case EntryType.custom:
        return [];
    }
  }

  List<Widget> _buildLoginFields(LoginEntry entry) {
    return [
      if (entry.username != null && entry.username!.isNotEmpty)
        _buildCopyableField('用户名', entry.username!, Icons.person, isSensitive: false),
      if (entry.email != null && entry.email!.isNotEmpty)
        _buildCopyableField('邮箱', entry.email!, Icons.email, isSensitive: false),
      if (entry.password != null && entry.password!.isNotEmpty)
        _buildCopyableField('密码', entry.password!, Icons.lock, isSensitive: true),
      if (entry.url != null && entry.url!.isNotEmpty)
        _buildUrlField('网站', entry.url!, Icons.link),
      if (_totpCode != null)
        _buildTotpField('验证码', _totpCode!, _totpRemainingSeconds ?? 30),
      if (entry.notes != null && entry.notes!.isNotEmpty)
        _buildNoteField('备注', entry.notes!),
    ];
  }

  List<Widget> _buildBankCardFields(BankCardEntry entry) {
    return [
      if (entry.cardNumber != null && entry.cardNumber!.isNotEmpty)
        _buildCopyableField('卡号', entry.cardNumber!, Icons.credit_card, isSensitive: true),
      if (entry.cardHolderName != null && entry.cardHolderName!.isNotEmpty)
        _buildDisplayField('持卡人', entry.cardHolderName!, Icons.person),
      if (entry.expiryMonth != null && entry.expiryYear != null)
        _buildDisplayField(
          '有效期',
          '${entry.expiryMonth.toString().padLeft(2, '0')}/${entry.expiryYear}',
          Icons.calendar_today,
        ),
      if (entry.cvv != null && entry.cvv!.isNotEmpty)
        _buildCopyableField('CVV', entry.cvv!, Icons.security, isSensitive: true),
      if (entry.bankName != null && entry.bankName!.isNotEmpty)
        _buildDisplayField('银行', entry.bankName!, Icons.account_balance),
      if (entry.cardType != null)
        _buildDisplayField('卡类型', EntryTypeHelper.getCardTypeName(entry.cardType!), Icons.payment),
    ];
  }

  List<Widget> _buildSecureNoteFields(SecureNoteEntry entry) {
    return [
      if (entry.isMarkdown)
        Container(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTokens.radiusL),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTokens.spaceS),
                  Text(
                    'Markdown 内容',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceM),
              Text(entry.content ?? ''),
            ],
          ),
        )
      else
        _buildNoteField('内容', entry.content ?? ''),
    ];
  }

  List<Widget> _buildIdentityFields(IdentityEntry entry) {
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
      if (entry.idNumber != null && entry.idNumber!.isNotEmpty)
        _buildCopyableField('证件号码', entry.idNumber!, Icons.badge, isSensitive: true),
      if (entry.phone != null && entry.phone!.isNotEmpty)
        _buildCopyableField('电话', entry.phone!, Icons.phone, isSensitive: false),
      if (entry.email != null && entry.email!.isNotEmpty)
        _buildCopyableField('邮箱', entry.email!, Icons.email, isSensitive: false),
      if (entry.address != null && entry.address!.isNotEmpty)
        _buildCopyableField('地址', entry.address!, Icons.location_on, isSensitive: false),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          showValue ? value : '••••••••',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSensitive)
              IconButton(
                icon: Icon(
                  _isSensitiveVisible(fieldKey)
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => _toggleSensitiveVisibility(fieldKey),
                tooltip: _isSensitiveVisible(fieldKey) ? '隐藏' : '显示',
              ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () => _copyToClipboard(value, label),
              tooltip: '复制',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayField(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildUrlField(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary.withAlpha(120),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              onPressed: () async {
                final uri = Uri.parse(value);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              tooltip: '打开链接',
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () => _copyToClipboard(value, label),
              tooltip: '复制',
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = progress < 0.3 ? colorScheme.error : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withAlpha(140),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.primary.withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: colorScheme.surface.withAlpha(80),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text(
                  '$remainingSeconds',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  '${code.substring(0, 3)} ${code.substring(3)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copyToClipboard(code, label),
            tooltip: '复制验证码',
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: AppTokens.spaceS),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildTagsSection(VaultEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: entry.tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  avatar: const Icon(Icons.tag_rounded, size: 16),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(VaultEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '元信息',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTokens.spaceS),
          _buildMetadataRow('创建时间', _formatDateTime(entry.createdAt)),
          _buildMetadataRow('更新时间', _formatDateTime(entry.updatedAt)),
          _buildMetadataRow('UUID', '${entry.uuid.substring(0, 8)}...'),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
