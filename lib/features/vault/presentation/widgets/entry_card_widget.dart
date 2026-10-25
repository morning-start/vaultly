import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../domain/vault_entry.dart';
import 'entry_type_helper.dart';
import '../../../../ui/theme/tokens.dart';
import '../../../../ui/theme/vaultly_colors.dart';
import '../../../../shared/widgets/type_badge.dart';

/// 条目卡片 v2
///
/// 减法重设计：去渐变条/双层阴影，保留类型色徽章；
/// 副信息为类型相关的实质内容（用户名/卡号尾号/笔记摘要/姓名）。
/// 支持滑动操作：右滑复制主字段（登录=密码，银行卡=卡号），左滑收藏。
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

  void _onTapDown(TapDownDetails details) =>
      setState(() => _isPressed = true);

  void _onTapUp(TapUpDetails details) => setState(() => _isPressed = false);

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = colorScheme.entryType(widget.entry.type);

    final card = GestureDetector(
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceM,
          vertical: AppTokens.spaceM,
        ),
        decoration: BoxDecoration(
          color: _isPressed
              ? colorScheme.surfaceContainerLow
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          border: Border.all(
            color: _isPressed
                ? typeColor.withAlpha(120)
                : colorScheme.outlineVariant.withAlpha(76),
            width: _isPressed ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            TypeBadge(type: widget.entry.type),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.entry.isFavorite) ...[
              const SizedBox(width: AppTokens.spaceS),
              Icon(Icons.star_rounded, size: 18, color: colorScheme.favorite),
            ],
          ],
        ),
      ),
    );

    final hasCopy = widget.onCopyPrimaryField != null;
    final hasFavorite = widget.onToggleFavorite != null;

    if (!hasCopy && !hasFavorite) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
      child: Slidable(
        key: ValueKey(widget.entry.id),
        endActionPane: hasFavorite
            ? ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: (_) => widget.onToggleFavorite!(),
                    backgroundColor: colorScheme.favorite.withAlpha(38),
                    foregroundColor: colorScheme.favorite,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(AppTokens.radiusL),
                    ),
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
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: (_) => widget.onCopyPrimaryField!(),
                    backgroundColor: colorScheme.primary.withAlpha(38),
                    foregroundColor: colorScheme.primary,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(AppTokens.radiusL),
                    ),
                    icon: Icons.copy_rounded,
                    label: '复制',
                  ),
                ],
              )
            : null,
        child: card,
      ),
    );
  }

  /// 类型相关的实质副信息
  String _subtitle(VaultEntry entry) {
    return switch (entry) {
      LoginEntry l => _firstNonEmpty([l.username, l.email, l.url]) ?? '登录凭证',
      BankCardEntry b => _cardTail(b),
      SecureNoteEntry n =>
        (n.content ?? '').isEmpty ? '安全笔记' : _noteSummary(n.content!),
      IdentityEntry i => _firstNonEmpty([
          [i.lastName, i.firstName].whereType<String>().join(' '),
          i.phone,
          i.email,
        ]) ?? '身份信息',
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
    final tail = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    final bank = (b.bankName ?? '').trim();
    if (tail.isEmpty && bank.isEmpty) return '银行卡';
    if (tail.isEmpty) return bank;
    if (bank.isEmpty) return '•••• $tail';
    return '$bank •••• $tail';
  }

  String _noteSummary(String content) {
    final firstLine =
        content.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return firstLine.isEmpty ? '安全笔记' : firstLine.trim();
  }
}
