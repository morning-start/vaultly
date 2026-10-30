import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/tools/presentation/password_generator_panel.dart';
import '../../../shared/widgets/type_badge.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../vault/domain/vault_entry.dart';
import '../../vault/presentation/vault_providers.dart';
import '../password_generator.dart';

/// 工具页（原型 tools.html）
///
/// 结构：大标题 → 密码生成器（页面化面板）→ 密码健康（统计 + 问题条目）
/// → 快捷录入（拍照识别银行卡 / 扫码添加 TOTP）。
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = ref.watch(vaultNotifierProvider).entries;
    final health = _analyze(entries);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colorScheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 120 + bottomInset),
          children: [
            Text('工具', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 4),
            Text(
              '生成、检查、快速录入',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.textMuted),
            ),
            const _SectionLabel('密码生成器'),
            _SurfaceCard(child: const PasswordGeneratorPanel()),
            const _SectionLabel('密码健康'),
            _SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _StatsRow(
                    weak: health.weak,
                    duplicate: health.duplicate,
                    stale: health.stale,
                  ),
                  if (health.issues.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: colorScheme.accent,
                          ),
                          const SizedBox(width: AppTokens.spaceS),
                          Text(
                            '暂未发现明显的密码风险',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final (entry, reason) in health.issues)
                      _IssueRow(entry: entry, reason: reason),
                ],
              ),
            ),
            const _SectionLabel('快捷录入'),
            _SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _QuickRow(
                    icon: Icons.photo_camera_outlined,
                    title: '拍照识别银行卡',
                    subtitle: '对准卡面，自动填入卡号',
                    onTap: () => context.push('/add?type=bankCard'),
                  ),
                  _QuickRow(
                    icon: Icons.qr_code_scanner_rounded,
                    title: '扫码添加 TOTP',
                    subtitle: '扫描二维码，直接生成验证码',
                    onTap: () => context.push('/add?type=login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统计弱密码 / 重复密码 / 90 天未更新，并给出问题条目摘要
  _PasswordHealth _analyze(List<VaultEntry> entries) {
    final logins = entries
        .whereType<LoginEntry>()
        .where((e) => (e.password ?? '').isNotEmpty)
        .toList();
    final byPassword = <String, List<LoginEntry>>{};
    for (final entry in logins) {
      byPassword.putIfAbsent(entry.password!, () => []).add(entry);
    }

    final now = DateTime.now();
    var weak = 0;
    var duplicate = 0;
    var stale = 0;
    final issues = <(VaultEntry, String)>[];

    for (final entry in logins) {
      final password = entry.password!;
      final group = byPassword[password]!;
      final days = now.difference(entry.updatedAt).inDays;
      final isWeak = PasswordGenerator.calculateStrength(password) < 40;
      final isDuplicate = group.length > 1;
      final isStale = days >= 90;

      if (isWeak) weak++;
      if (isDuplicate) duplicate++;
      if (isStale) stale++;

      if (issues.length >= 3) continue;

      if (isWeak) {
        issues.add((entry, isStale ? '弱密码 · $days 天未更新' : '弱密码'));
      } else if (isDuplicate) {
        final other = group.firstWhere(
          (e) => e.id != entry.id,
          orElse: () => entry,
        );
        issues.add((entry, '与「${other.title}」密码重复'));
      } else if (isStale) {
        issues.add((entry, '$days 天未更新'));
      }
    }

    return _PasswordHealth(
      weak: weak,
      duplicate: duplicate,
      stale: stale,
      issues: issues,
    );
  }
}

class _PasswordHealth {
  final int weak;
  final int duplicate;
  final int stale;
  final List<(VaultEntry, String)> issues;

  const _PasswordHealth({
    required this.weak,
    required this.duplicate,
    required this.stale,
    required this.issues,
  });
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: Theme.of(context).colorScheme.textMuted,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.spaceL),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 三列统计（弱密码 / 重复密码 / 90 天未更新）
class _StatsRow extends StatelessWidget {
  final int weak;
  final int duplicate;
  final int stale;

  const _StatsRow({
    required this.weak,
    required this.duplicate,
    required this.stale,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warning = colorScheme.isDark
        ? AppTokens.warningDark
        : AppTokens.warningLight;

    Widget stat(String value, String label, {Color? color}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color ?? colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colorScheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('$weak', '弱密码', color: weak > 0 ? warning : null),
        Container(width: 1, height: 40, color: colorScheme.hairline),
        stat('$duplicate', '重复密码', color: duplicate > 0 ? warning : null),
        Container(width: 1, height: 40, color: colorScheme.hairline),
        stat('$stale', '90 天未更新'),
      ],
    );
  }
}

/// 问题条目行
class _IssueRow extends StatelessWidget {
  final VaultEntry entry;
  final String reason;

  const _IssueRow({required this.entry, required this.reason});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.push('/entry/${entry.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.hairline)),
        ),
        child: Row(
          children: [
            TypeBadge(type: entry.type),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// 快捷录入行
class _QuickRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.hairline)),
        ),
        child: Row(
          children: [
            Container(
              width: AppTokens.iconBadgeSize,
              height: AppTokens.iconBadgeSize,
              decoration: BoxDecoration(
                color: colorScheme.primarySoft,
                borderRadius: BorderRadius.circular(AppTokens.badgeRadius),
              ),
              child: Icon(icon, size: 22, color: colorScheme.primary),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
