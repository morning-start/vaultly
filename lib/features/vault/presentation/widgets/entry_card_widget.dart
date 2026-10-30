import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../domain/vault_entry.dart';
import 'entry_type_helper.dart';
import 'totp_pill.dart';
import '../../../../ui/theme/tokens.dart';
import '../../../../ui/theme/vaultly_colors.dart';
import '../../../../shared/widgets/type_badge.dart';

/// 条目行（原型 `.row`）
///
/// 行式布局：类型徽章 44 + 标题 16/500 + 副标题 12 muted + 行尾状态
/// （TOTP 胶囊 / 收藏星标 / chevron）。行高不小于 64，按压高亮 surface-2。
/// 支持滑动操作：右滑复制主字段（登录=密码，银行卡=卡号），左滑收藏。
/// 背景与分隔线由外层分组卡片负责，本组件保持透明。
class EntryCardWidget extends StatefulWidget {
  final VaultEntry entry;
  final VoidCallback onTap;

  /// 右滑复制主字段的回调（null 则不启用滑动复制）
  final VoidCallback? onCopyPrimaryField;

  /// 左滑切换收藏的回调（null 则不启用滑动收藏）
  final VoidCallback? onToggleFavorite;

  const EntryCardWidget({
    super.key,
    required this.entry,
    required this.onTap,
    this.onCopyPrimaryField,
    this.onToggleFavorite,
  });

  @override
  State<EntryCardWidget> createState() => _EntryCardWidgetState();
}

class _EntryCardWidgetState extends State<EntryCardWidget> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) => setState(() => _isPressed = true);

  void _onTapUp(TapUpDetails details) => setState(() => _isPressed = false);

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totpSecret = switch (widget.entry) {
      LoginEntry l when (l.totpSecret ?? '').isNotEmpty => l.totpSecret,
      _ => null,
    };

    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: AppTokens.animTap,
        curve: AppTokens.easeStandard,
        constraints: const BoxConstraints(
          minHeight: AppTokens.listRowMinHeight,
        ),
        padding: AppTokens.listRowPadding,
        color: _isPressed ? colorScheme.surfaceAlt : Colors.transparent,
        child: Row(
          children: [
            TypeBadge(type: widget.entry.type),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(widget.entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (totpSecret != null) ...[
              const SizedBox(width: AppTokens.spaceS),
              TotpPill(secret: totpSecret),
            ],
            if (widget.entry.isFavorite) ...[
              const SizedBox(width: AppTokens.spaceS),
              Icon(Icons.star_rounded, size: 18, color: colorScheme.favorite),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.textFaint,
            ),
          ],
        ),
      ),
    );

    final hasCopy = widget.onCopyPrimaryField != null;
    final hasFavorite = widget.onToggleFavorite != null;

    if (!hasCopy && !hasFavorite) return row;

    return Slidable(
      key: ValueKey(widget.entry.id),
      endActionPane: hasFavorite
          ? ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.3,
              children: [
                SlidableAction(
                  onPressed: (_) => widget.onToggleFavorite!(),
                  backgroundColor: colorScheme.favorite.withAlpha(38),
                  foregroundColor: colorScheme.favorite,
                  icon: widget.entry.isFavorite
                      ? Icons.star_outline_rounded
                      : Icons.star_rounded,
                  label: widget.entry.isFavorite ? '取消收藏' : '收藏',
                ),
              ],
            )
          : null,
      startActionPane: hasCopy
          ? ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.3,
              children: [
                SlidableAction(
                  onPressed: (_) => widget.onCopyPrimaryField!(),
                  backgroundColor: colorScheme.primarySoft,
                  foregroundColor: colorScheme.primary,
                  icon: Icons.copy_rounded,
                  label: '复制',
                ),
              ],
            )
          : null,
      child: row,
    );
  }

  /// 类型相关的实质副信息
  String _subtitle(VaultEntry entry) {
    return switch (entry) {
      LoginEntry l => _firstNonEmpty([l.username, l.email, l.url]) ?? '登录凭证',
      BankCardEntry b => _cardTail(b),
      SecureNoteEntry n =>
        (n.content ?? '').isEmpty ? '安全笔记' : _noteSummary(n.content!),
      IdentityEntry i =>
        _firstNonEmpty([
              [i.lastName, i.firstName].whereType<String>().join(' '),
              i.phone,
              i.email,
            ]) ??
            '身份信息',
      _ => EntryTypeHelper.getName(entry.type),
    };
  }

  String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  String _cardTail(BankCardEntry b) {
    final digits = (b.cardNumber ?? '').replaceAll(' ', '');
    final tail = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    final bank = (b.bankName ?? '').trim();
    if (tail.isEmpty && bank.isEmpty) return '银行卡';
    if (tail.isEmpty) return bank;
    if (bank.isEmpty) return '•••• $tail';
    return '$bank •••• $tail';
  }

  String _noteSummary(String content) {
    final firstLine = content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return firstLine.isEmpty ? '安全笔记' : firstLine.trim();
  }
}
