import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/vault_entry.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/field_row.dart';
import '../../../shared/widgets/mono_text.dart';
import '../../../shared/widgets/type_badge.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../../features/tools/totp_service.dart';
import '../../../features/tools/clipboard_service.dart';
import 'widgets/entry_type_helper.dart';

/// 条目详情页
///
/// 紧凑头部（类型徽章 + 标题 + 类型 chip + 时间）替代原渐变 Hero；
/// 字段统一 [FieldRow]（点按复制 + ✓ 反馈）；TOTP 大号等宽分组 +
/// 环形倒计时；银行卡可视化卡面。
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
  String? _totpCode;
  int? _totpRemainingSeconds;
  Timer? _totpTimer;

  @override
  void initState() {
    super.initState();
    final entry = ref.read(vaultEntryByIdProvider(widget.entryId));
    if (entry is LoginEntry && (entry.totpSecret ?? '').isNotEmpty) {
      _startTotpTimer();
    }
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
  }

  void _startTotpTimer() {
    _updateTotp();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTotp();
    });
  }

  void _updateTotp() {
    final entry = ref.read(vaultEntryByIdProvider(widget.entryId));
    if (entry is LoginEntry && (entry.totpSecret ?? '').isNotEmpty) {
      final totpService = TOTPService();
      final code = totpService.generateTOTP(entry.totpSecret!);
      final remaining = totpService.getRemainingSeconds();

      if (mounted) {
        setState(() {
          _totpCode = code;
          _totpRemainingSeconds = remaining;
        });
      }
    }
  }

  Future<void> _deleteEntry(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '确认删除',
        content: '确定要删除 "${entry.title}" 吗？此操作不可恢复。',
        confirmLabel: '删除',
        isDangerous: true,
      ),
    );

    if (confirmed == true) {
      await ref
          .read(vaultNotifierProvider.notifier)
          .deleteEntry(entry.uuid);
      if (mounted) {
        context.pop();
      }
    }
  }

  Future<void> _toggleFavorite(VaultEntry entry) async {
    await ref
        .read(vaultNotifierProvider.notifier)
        .toggleFavorite(entry.uuid);
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(vaultEntryByIdProvider(widget.entryId));

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = colorScheme.entryType(entry.type);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: Icon(
              entry.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: entry.isFavorite ? colorScheme.favorite : null,
            ),
            onPressed: () => _toggleFavorite(entry),
            tooltip: entry.isFavorite ? '取消收藏' : '收藏',
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/entry/${entry.uuid}/edit'),
            tooltip: '编辑',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded,
                        color: colorScheme.error, size: 20),
                    const SizedBox(width: AppTokens.spaceS),
                    Text('删除', style: TextStyle(color: colorScheme.error)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') _deleteEntry(entry);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 紧凑头部
            Row(
              children: [
                TypeBadge(type: entry.type, size: 56),
                const SizedBox(width: AppTokens.spaceL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: colorScheme.onSurface),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTokens.spaceXS),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.spaceS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(
                                  AppTokens.radiusStadium),
                            ),
                            child: Text(
                              EntryTypeHelper.getName(entry.type),
                              style:
                                  Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: typeColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.spaceS),
                          Flexible(
                            child: Text(
                              '更新于 ${_formatDate(entry.updatedAt)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXL),

            // 类型特定内容
            ..._buildTypeSpecificFields(entry),

            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceL),
              _buildTagsSection(entry),
            ],

            const SizedBox(height: AppTokens.spaceXL),
            _buildMetadataSection(entry),
            const SizedBox(height: AppTokens.spaceXXL),
          ],
        ),
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
      if ((entry.username ?? '').isNotEmpty)
        FieldRow(
          label: '用户名',
          value: entry.username!,
          icon: Icons.person_rounded,
        ),
      if ((entry.email ?? '').isNotEmpty)
        FieldRow(
          label: '邮箱',
          value: entry.email!,
          icon: Icons.email_rounded,
        ),
      if ((entry.password ?? '').isNotEmpty)
        FieldRow(
          label: '密码',
          value: entry.password!,
          icon: Icons.password_rounded,
          isSensitive: true,
        ),
      if ((entry.url ?? '').isNotEmpty)
        FieldRow(
          label: '网站',
          value: entry.url!,
          icon: Icons.link_rounded,
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            tooltip: '打开链接',
            onPressed: () async {
              final uri = Uri.parse(entry.url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      if (_totpCode != null && _totpRemainingSeconds != null)
        _buildTotpField(_totpCode!, _totpRemainingSeconds!),
      if ((entry.notes ?? '').isNotEmpty)
        _buildNoteField('备注', entry.notes!),
    ];
  }

  List<Widget> _buildBankCardFields(BankCardEntry entry) {
    final digits = (entry.cardNumber ?? '').replaceAll(' ', '');
    final tail =
        digits.length >= 4 ? digits.substring(digits.length - 4) : digits;

    return [
      // 可视化卡面
      Container(
        height: 180,
        padding: const EdgeInsets.all(AppTokens.spaceL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.bankCard.withAlpha(50),
              Theme.of(context).colorScheme.bankCard.withAlpha(18),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          border: Border.all(
            color: Theme.of(context).colorScheme.bankCard.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (entry.bankName ?? '').isNotEmpty ? entry.bankName! : '银行卡',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.bankCard,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (entry.cardType != null)
                  Text(
                    EntryTypeHelper.getCardTypeName(entry.cardType!),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.bankCard,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
            const Spacer(),
            MonoText(
              tail.isEmpty ? '•••• •••• •••• ••••' : '•••• •••• •••• $tail',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if ((entry.cardHolderName ?? '').isNotEmpty)
                  Text(
                    entry.cardHolderName!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (entry.expiryMonth != null && entry.expiryYear != null)
                  Text(
                    '${entry.expiryMonth.toString().padLeft(2, '0')}/${entry.expiryYear}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: AppTokens.monoFamily,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppTokens.spaceL),
      if ((entry.cardNumber ?? '').isNotEmpty)
        FieldRow(
          label: '卡号',
          value: entry.cardNumber!,
          icon: Icons.credit_card_rounded,
          isSensitive: true,
        ),
      if ((entry.cardHolderName ?? '').isNotEmpty)
        FieldRow(
          label: '持卡人',
          value: entry.cardHolderName!,
          icon: Icons.person_rounded,
        ),
      if (entry.expiryMonth != null && entry.expiryYear != null)
        FieldRow(
          label: '有效期',
          value:
              '${entry.expiryMonth.toString().padLeft(2, '0')}/${entry.expiryYear}',
          icon: Icons.calendar_today_rounded,
        ),
      if ((entry.cvv ?? '').isNotEmpty)
        FieldRow(
          label: 'CVV',
          value: entry.cvv!,
          icon: Icons.security_rounded,
          isSensitive: true,
        ),
    ];
  }

  List<Widget> _buildSecureNoteFields(SecureNoteEntry entry) {
    return [
      _buildNoteField(
        entry.isMarkdown ? 'Markdown 内容' : '内容',
        entry.content ?? '',
      ),
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
        FieldRow(
          label: '姓名',
          value: nameParts,
          icon: Icons.person_rounded,
        ),
      if (entry.birthDate != null)
        FieldRow(
          label: '出生日期',
          value: _formatDate(entry.birthDate!),
          icon: Icons.cake_rounded,
        ),
      if ((entry.idNumber ?? '').isNotEmpty)
        FieldRow(
          label: '证件号码',
          value: entry.idNumber!,
          icon: Icons.badge_rounded,
          isSensitive: true,
        ),
      if ((entry.phone ?? '').isNotEmpty)
        FieldRow(
          label: '电话',
          value: entry.phone!,
          icon: Icons.phone_rounded,
        ),
      if ((entry.email ?? '').isNotEmpty)
        FieldRow(
          label: '邮箱',
          value: entry.email!,
          icon: Icons.email_rounded,
        ),
      if ((entry.address ?? '').isNotEmpty)
        FieldRow(
          label: '地址',
          value: entry.address!,
          icon: Icons.location_on_rounded,
        ),
    ];
  }

  Widget _buildTotpField(String code, int remainingSeconds) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = remainingSeconds / 30;
    final color = progress < 0.3 ? colorScheme.error : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(
        top: AppTokens.spaceS,
        bottom: AppTokens.spaceS,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.primary.withAlpha(40)),
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
                  backgroundColor: colorScheme.surface.withAlpha(120),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text(
                  '$remainingSeconds',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                  '验证码',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                MonoText(
                  '${code.substring(0, 3)} ${code.substring(3)}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          _CopyIconButton(
            value: code,
            tooltip: '复制验证码',
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppTokens.spaceS),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildTagsSection(VaultEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('标签', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: entry.tags
              .map((tag) => Chip(
                    label: Text(tag),
                    avatar: const Icon(Icons.tag_rounded, size: 14),
                    visualDensity: VisualDensity.compact,
                  ))
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
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('关于此条目', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppTokens.spaceS),
          _buildMetadataRow('创建时间', _formatDateTime(entry.createdAt)),
          _buildMetadataRow('更新时间', _formatDateTime(entry.updatedAt)),
          _buildMetadataRow('UUID', '${entry.uuid.substring(0, 8)}…'),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
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

/// TOTP 专用复制按钮（复制后自动清除）
class _CopyIconButton extends StatelessWidget {
  final String value;
  final String tooltip;

  const _CopyIconButton({
    required this.value,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 20),
      onPressed: () async {
        await ClipboardService().copyTOTP(value);
        if (context.mounted) {
          AppToast.show(context, '验证码已复制（30 秒后自动清除）');
        }
      },
      tooltip: tooltip,
    );
  }
}
