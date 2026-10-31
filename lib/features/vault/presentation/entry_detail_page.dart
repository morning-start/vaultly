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
import '../../../features/tools/password_policy.dart';
import '../../../features/tools/presentation/password_strength_indicator.dart';
import '../../../features/tools/totp_service.dart';
import '../../../features/tools/clipboard_service.dart';
import 'widgets/entry_type_helper.dart';

/// 条目详情页（原型 detail.html）
///
/// 结构：52 高顶栏（返回 / 标题 / 收藏 / 更多）
/// → 条目头（56 徽章 + 名称 + 类型 tag + 更新时间）
/// → TOTP 主卡片（34 大码 + 46 环倒计时）
/// → 凭证 / 整理 / 备注 分组卡片 → 页脚元信息 → 底部删除 + 编辑操作栏。
class EntryDetailPage extends ConsumerStatefulWidget {
  final String entryId;

  const EntryDetailPage({super.key, required this.entryId});

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
    // ADR-006 R3：删除是「移入回收站」（打墓碑继续同步），不是立刻抹掉，
    // 因此文案不能再写「不可恢复」。
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '移入回收站',
        content: '「${entry.title}」将移入回收站，30 天内可以恢复；'
            '删除记录也会同步到其他设备。',
        confirmLabel: '删除',
        icon: Icons.delete_outline_rounded,
        isDangerous: true,
      ),
    );

    if (confirmed == true) {
      final ok = await ref
          .read(vaultNotifierProvider.notifier)
          .deleteEntry(entry.id);
      if (!mounted) return;

      if (ok) {
        // 先弹提示再 pop：pop 之后本页 context 就可能失效，取不到根 Overlay
        AppToast.show(context, '已移入回收站');
        context.pop();
      } else {
        AppToast.show(
          context,
          ref.read(vaultNotifierProvider).error ?? '删除失败，请重试',
        );
      }
    }
  }

  Future<void> _toggleFavorite(VaultEntry entry) async {
    await ref.read(vaultNotifierProvider.notifier).toggleFavorite(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(vaultEntryByIdProvider(widget.entryId));
    final colorScheme = Theme.of(context).colorScheme;

    if (entry == null) {
      // 已加载完却找不到条目：多半是它被删除（本机或另一台设备同步过来的墓碑），
      // 直接说明情况，不要一直转圈让人以为还在加载。
      final loaded = ref.watch(vaultNotifierProvider).isLoaded;

      return Scaffold(
        backgroundColor: colorScheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildNavBar(null),
              Expanded(
                child: Center(
                  child: loaded
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 40,
                              color: colorScheme.textMuted,
                            ),
                            const SizedBox(height: AppTokens.spaceM),
                            Text(
                              '条目不存在或已移入回收站',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: colorScheme.textMuted),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavBar(entry),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(entry),
                    if (_totpCode != null && _totpRemainingSeconds != null)
                      _buildTotpCard(_totpCode!, _totpRemainingSeconds!),
                    ..._buildCredentialSection(entry),
                    ..._buildOrganizeSection(entry),
                    ..._buildNoteSection(entry),
                    _buildFooter(entry),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(entry),
    );
  }

  // ==================== 顶栏 ====================

  Widget _buildNavBar(VaultEntry? entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: AppTokens.navBarHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
              tooltip: '返回',
            ),
          ),
          Text('条目详情', style: textTheme.titleMedium),
          if (entry != null)
            Positioned(
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      entry.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 22,
                      color: entry.isFavorite
                          ? colorScheme.favorite
                          : colorScheme.onSurface,
                    ),
                    onPressed: () => _toggleFavorite(entry),
                    tooltip: entry.isFavorite ? '取消收藏' : '收藏',
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 22,
                      color: colorScheme.onSurface,
                    ),
                    tooltip: '更多操作',
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppTokens.spaceS),
                            Text(
                              '删除条目',
                              style: TextStyle(color: colorScheme.error),
                            ),
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
            ),
        ],
      ),
    );
  }

  // ==================== 条目头 ====================

  Widget _buildHero(VaultEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = colorScheme.entryType(entry.type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
      child: Row(
        children: [
          TypeBadge(type: entry.type, size: AppTokens.iconBadgeLarge),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(38),
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusStadium,
                        ),
                      ),
                      child: Text(
                        EntryTypeHelper.getName(entry.type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _relativeUpdated(entry.updatedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOTP 主卡片 ====================

  Widget _buildTotpCard(String code, int remainingSeconds) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = remainingSeconds / 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withAlpha(46),
            colorScheme.surfaceCard.withAlpha(0),
          ],
          stops: const [0, 0.6],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.primary.withAlpha(82)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: colorScheme.surfaceTrack,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  '$remainingSeconds',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '两步验证码 · 每 30 秒刷新',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.textMuted),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    MonoText(
                      code.substring(0, 3),
                      style: _totpCodeStyle(colorScheme),
                    ),
                    Text(
                      ' ',
                      style: _totpCodeStyle(
                        colorScheme,
                      ).copyWith(color: colorScheme.textFaint),
                    ),
                    MonoText(
                      code.substring(3),
                      style: _totpCodeStyle(colorScheme),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _TotpCopyButton(value: code),
        ],
      ),
    );
  }

  TextStyle _totpCodeStyle(ColorScheme colorScheme) {
    return TextStyle(
      fontFamily: AppTokens.monoFamily,
      fontSize: AppTokens.textDisplay,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      height: 1.1,
      color: colorScheme.onSurface,
    );
  }

  // ==================== 凭证 ====================

  List<Widget> _buildCredentialSection(VaultEntry entry) {
    final rows = _buildFieldRows(entry);
    final cardVisual = entry is BankCardEntry
        ? [_buildBankCardVisual(entry)]
        : [];
    if (rows.isEmpty && cardVisual.isEmpty) return [];

    return [
      _sectionLabel('凭证'),
      ...cardVisual,
      if (rows.isNotEmpty) _fieldCard(rows),
    ];
  }

  List<Widget> _buildFieldRows(VaultEntry entry) {
    return switch (entry) {
      LoginEntry e => [
        if ((e.username ?? '').isNotEmpty)
          FieldRow(label: '用户名', value: e.username!),
        if ((e.email ?? '').isNotEmpty) FieldRow(label: '邮箱', value: e.email!),
        if ((e.password ?? '').isNotEmpty)
          FieldRow(
            label: '密码',
            value: e.password!,
            isSensitive: true,
            footer: _buildStrengthBar(e.password!),
          ),
        if ((e.url ?? '').isNotEmpty)
          FieldRow(
            label: '网址',
            value: e.url!,
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              tooltip: '打开链接',
              onPressed: () async {
                final uri = Uri.parse(e.url!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
      ],
      BankCardEntry e => [
        if ((e.cardNumber ?? '').isNotEmpty)
          FieldRow(label: '卡号', value: e.cardNumber!, isSensitive: true),
        if ((e.cardHolderName ?? '').isNotEmpty)
          FieldRow(label: '持卡人', value: e.cardHolderName!),
        if (e.expiryMonth != null && e.expiryYear != null)
          FieldRow(
            label: '有效期',
            value:
                '${e.expiryMonth.toString().padLeft(2, '0')}/${e.expiryYear}',
          ),
        if ((e.cvv ?? '').isNotEmpty)
          FieldRow(label: 'CVV', value: e.cvv!, isSensitive: true),
      ],
      IdentityEntry e => [
        if (_identityName(e).isNotEmpty)
          FieldRow(label: '姓名', value: _identityName(e)),
        if (e.birthDate != null)
          FieldRow(label: '出生日期', value: _formatDate(e.birthDate!)),
        if ((e.idNumber ?? '').isNotEmpty)
          FieldRow(label: '证件号码', value: e.idNumber!, isSensitive: true),
        if ((e.phone ?? '').isNotEmpty) FieldRow(label: '电话', value: e.phone!),
        if ((e.email ?? '').isNotEmpty) FieldRow(label: '邮箱', value: e.email!),
        if ((e.address ?? '').isNotEmpty)
          FieldRow(label: '地址', value: e.address!),
      ],
      _ => const [],
    };
  }

  Widget _buildStrengthBar(String password) {
    final strength = PasswordPolicy.calculateStrength(password);
    if (strength == 0) return const SizedBox.shrink();
    return PasswordStrengthIndicator(
      strength: strength,
      height: 4,
      showLabel: false,
    );
  }

  Widget _buildBankCardVisual(BankCardEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final digits = (entry.cardNumber ?? '').replaceAll(' ', '');
    final tail = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    final typeColor = colorScheme.bankCard;

    return Container(
      height: 176,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [typeColor.withAlpha(46), colorScheme.surfaceCard],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: typeColor.withAlpha(70)),
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
                  color: typeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.cardType != null)
                Text(
                  EntryTypeHelper.getCardTypeName(entry.cardType!),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: typeColor),
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
          const SizedBox(height: 12),
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
    );
  }

  // ==================== 整理 ====================

  List<Widget> _buildOrganizeSection(VaultEntry entry) {
    final hasFolder = (entry.folderId ?? '').isNotEmpty;
    final hasTags = entry.tags.isNotEmpty;
    if (!hasFolder && !hasTags) return [];

    final colorScheme = Theme.of(context).colorScheme;

    return [
      _sectionLabel('整理'),
      _fieldCard([
        if (hasFolder)
          _OrganizeRow(
            icon: Icons.folder_outlined,
            title: '文件夹',
            color: colorScheme.primary,
            showChevron: true,
            child: Text(
              entry.folderId!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.textMuted),
            ),
          ),
        if (hasTags)
          _OrganizeRow(
            icon: Icons.sell_outlined,
            title: '标签',
            color: colorScheme.primary,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in entry.tags)
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusStadium,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ]),
    ];
  }

  // ==================== 备注 ====================

  List<Widget> _buildNoteSection(VaultEntry entry) {
    final note = switch (entry) {
      LoginEntry e when (e.notes ?? '').trim().isNotEmpty => e.notes!,
      SecureNoteEntry e when (e.content ?? '').trim().isNotEmpty => e.content!,
      _ => null,
    };
    if (note == null) return [];

    final colorScheme = Theme.of(context).colorScheme;

    return [
      _sectionLabel('备注'),
      _fieldCard([
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.65,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ]),
    ];
  }

  // ==================== 页脚与操作栏 ====================

  Widget _buildFooter(VaultEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        '创建于 ${_formatDate(entry.createdAt)} · 最近更新 ${_formatDate(entry.updatedAt)}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.textMuted,
          height: 1.8,
        ),
      ),
    );
  }

  Widget _buildActionBar(VaultEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [colorScheme.bg, colorScheme.bg.withAlpha(0)],
        ),
      ),
      child: Row(
        children: [
          Material(
            color: colorScheme.dangerSoft,
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusM),
              onTap: () => _deleteEntry(entry),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: colorScheme.error,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.push('/entry/${entry.id}/edit'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('编辑条目'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 小组件 ====================

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: Theme.of(context).colorScheme.textMuted,
        ),
      ),
    );
  }

  Widget _fieldCard(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(
          Divider(height: 1, thickness: 1, color: colorScheme.hairline),
        );
      }
      items.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }

  String _identityName(IdentityEntry entry) {
    return [
      entry.lastName,
      entry.middleName,
      entry.firstName,
    ].where((p) => p != null && p.isNotEmpty).join(' ');
  }

  String _relativeUpdated(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚更新';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前更新';
    if (diff.inDays < 1) return '${diff.inHours} 小时前更新';
    if (diff.inDays < 30) return '${diff.inDays} 天前更新';
    return '${_formatDate(date)} 更新';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

/// 整理分组行：36 徽章 + 标题 + 值区（标签 chips）
class _OrganizeRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  final bool showChevron;

  const _OrganizeRow({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primarySoft,
              borderRadius: BorderRadius.circular(AppTokens.radiusS),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
          if (showChevron)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.textFaint,
            ),
        ],
      ),
    );
  }
}

/// TOTP 复制按钮（主色浅底 + 32% 主色描边，复制后自动清除）
class _TotpCopyButton extends StatelessWidget {
  final String value;

  const _TotpCopyButton({required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primarySoft,
      borderRadius: BorderRadius.circular(AppTokens.radiusM - 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusM - 2),
        onTap: () async {
          await ClipboardService().copyTOTP(value);
          if (context.mounted) {
            AppToast.show(context, '验证码已复制（30 秒后自动清除）');
          }
        },
        child: Semantics(
          button: true,
          label: '复制验证码',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusM - 2),
              border: Border.all(color: colorScheme.primary.withAlpha(82)),
            ),
            child: Icon(
              Icons.content_copy_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
