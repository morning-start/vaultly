import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_info.dart';
import '../../../core/services/auto_lock_service.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../sync/presentation/sync_providers.dart';
import '../../vault/presentation/vault_providers.dart';
import '../settings_providers.dart';
import 'auth_lock_bridge.dart';

/// 设置中心（原型 settings.html）
///
/// 结构：大标题 → 保险库状态卡片 → 安全 / 同步 / 外观 / 关于 分组卡片
/// → 页脚隐私说明。行式设置项（标题 + 值 + chevron / switch）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final syncState = ref.watch(webDAVConfigProvider);
    final entryCount = ref.watch(vaultNotifierProvider).entries.length;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colorScheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 120 + bottomInset),
          children: [
            Text('设置', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: AppTokens.spaceL),
            _VaultStatusCard(
              entryCount: entryCount,
              isConfigured: syncState.isConfigured,
              lastSyncTime: syncState.lastSyncTime,
            ),
            const _SectionLabel('安全'),
            _SettingsCard(
              children: [
                _SettingRow(
                  title: '自动锁定',
                  value: '闲置 ${settings.autoLockMinutes} 分钟',
                  onTap: () =>
                      _pickAutoLock(context, ref, settings.autoLockMinutes),
                ),
                _SettingRow(
                  title: '生物识别解锁',
                  subtitle: '使用指纹或面容快速解锁',
                  onTap: () => context.push('/settings/biometric'),
                ),
                _SettingRow(
                  title: '剪贴板自动清理',
                  value: '30 秒',
                  trailing: Switch(
                    value: settings.clipboardAutoClear,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .setClipboardAutoClear(v),
                  ),
                ),
              ],
            ),
            const _SectionLabel('同步'),
            _SettingsCard(
              children: [
                _SettingRow(
                  title: 'WebDAV 同步',
                  value: syncState.isConfigured ? '已配置' : '未配置',
                  trailing: _StatusPill(
                    label: syncState.isConfigured ? '已启用' : '未启用',
                    active: syncState.isConfigured,
                  ),
                  onTap: () => context.push('/webdav'),
                ),
                _SettingRow(
                  title: '立即同步',
                  value: _syncTimeLabel(syncState.lastSyncTime),
                  trailing: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: colorScheme.textMuted,
                  ),
                  onTap: () => context.push('/webdav'),
                ),
              ],
            ),
            const _SectionLabel('外观'),
            _SettingsCard(
              children: [
                _SettingRow(
                  title: '主题',
                  value: _themeModeLabel(settings.themeMode),
                  onTap: () => _pickThemeMode(context, ref, settings.themeMode),
                ),
              ],
            ),
            const _SectionLabel('关于'),
            _SettingsCard(
              children: [
                const _SettingRow(title: '版本', value: AppInfo.version),
                _SettingRow(
                  title: '开源许可',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Vaultly',
                    applicationVersion: AppInfo.version,
                  ),
                ),
                _SettingRow(
                  title: '立即锁定',
                  danger: true,
                  onTap: () {
                    ref.read(authLockBridgeProvider.notifier).state();
                    context.go('/unlock');
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Vaultly · 数据只属于你\n本地加密存储，永不上传第三方服务器',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.8,
                color: colorScheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  static String _syncTimeLabel(DateTime? time) {
    if (time == null) return '尚未同步';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${time.month}/${time.day}';
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) {
    return showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('主题模式'),
        children: [
          for (final mode in ThemeMode.values)
            _OptionTile(
              label: _themeModeLabel(mode),
              selected: mode == current,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeMode(mode);
                Navigator.pop(dialogContext);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickAutoLock(BuildContext context, WidgetRef ref, int current) {
    return showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('自动锁定时间'),
        children: [
          for (final minutes in AutoLockService.lockDurations)
            _OptionTile(
              label: '$minutes 分钟',
              selected: minutes == current,
              onTap: () {
                ref.read(settingsProvider.notifier).setAutoLockMinutes(minutes);
                Navigator.pop(dialogContext);
              },
            ),
        ],
      ),
    );
  }
}

/// 保险库状态卡片
class _VaultStatusCard extends StatelessWidget {
  final int entryCount;
  final bool isConfigured;
  final DateTime? lastSyncTime;

  const _VaultStatusCard({
    required this.entryCount,
    required this.isConfigured,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final synced = isConfigured && lastSyncTime != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: AppTokens.iconBadgeLarge,
            height: AppTokens.iconBadgeLarge,
            decoration: BoxDecoration(
              color: colorScheme.primarySoft,
              borderRadius: BorderRadius.circular(AppTokens.badgeRadiusLarge),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 28,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('保险库已加密', style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'AES-256-GCM · Argon2id 派生\n$entryCount 个条目 · 本地存储',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(label: synced ? '已同步' : '未同步', active: synced),
        ],
      ),
    );
  }
}

/// 状态胶囊（原型 `.pill.ok` / `.pill.neutral`）
class _StatusPill extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.accent : colorScheme.textMuted;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? colorScheme.accentSoft : colorScheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusStadium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Icon(Icons.check_rounded, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
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

/// 设置分组卡片
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
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
}

/// 设置行（原型 `.row.row-tight`）
class _SettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingRow({
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: danger ? colorScheme.error : colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.textMuted,
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: AppTokens.spaceS),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.textFaint,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}

/// 选项行（对话框内）
class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
