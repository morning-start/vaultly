import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auto_lock_service.dart';
import '../../../ui/theme/tokens.dart';
import '../settings_providers.dart';
import 'auth_lock_bridge.dart';

/// 设置中心
///
/// 收纳：外观（主题模式）、安全（自动锁定/生物识别/剪贴板）、
/// 同步（WebDAV）、关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceS),
        children: [
          const _Section(label: '外观'),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            iconColor: colorScheme.primary,
            title: '主题模式',
            subtitle: _themeModeLabel(settings.themeMode),
            onTap: () => _pickThemeMode(context, ref, settings.themeMode),
          ),
          const _Section(label: '安全'),
          _SettingTile(
            icon: Icons.timer_outlined,
            iconColor: colorScheme.primary,
            title: '自动锁定',
            subtitle: '闲置 ${settings.autoLockMinutes} 分钟后自动锁定保险库',
            onTap: () =>
                _pickAutoLock(context, ref, settings.autoLockMinutes),
          ),
          _SettingTile(
            icon: Icons.content_copy_rounded,
            iconColor: colorScheme.primary,
            title: '剪贴板自动清除',
            subtitle: settings.clipboardAutoClear
                ? '复制敏感信息 30 秒后自动清除'
                : '已关闭，敏感信息将保留在剪贴板',
            trailing: Switch(
              value: settings.clipboardAutoClear,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setClipboardAutoClear(v),
            ),
          ),
          _SettingTile(
            icon: Icons.fingerprint_rounded,
            iconColor: colorScheme.primary,
            title: '生物识别解锁',
            subtitle: '使用指纹或面容快速解锁',
            onTap: () => context.push('/settings/biometric'),
          ),
          _SettingTile(
            icon: Icons.cloud_outlined,
            iconColor: colorScheme.primary,
            title: 'WebDAV 同步',
            subtitle: '备份与恢复保险库数据',
            onTap: () => context.push('/webdav'),
          ),
          const _Section(label: '关于'),
          const _SettingTile(
            icon: Icons.info_outline,
            iconColor: Color(0xFF4F46E5),
            title: '版本',
            subtitle: 'Vaultly 2.4.1',
          ),
          _SettingTile(
            icon: Icons.lock_outline,
            iconColor: colorScheme.error,
            title: '立即锁定',
            subtitle: '锁定保险库并返回解锁页',
            onTap: () {
              ref.read(authLockBridgeProvider.notifier).state();
              context.go('/unlock');
            },
          ),
        ],
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

  Future<void> _pickThemeMode(
      BuildContext context, WidgetRef ref, ThemeMode current) {
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

  Future<void> _pickAutoLock(
      BuildContext context, WidgetRef ref, int current) {
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
                ref
                    .read(settingsProvider.notifier)
                    .setAutoLockMinutes(minutes);
                Navigator.pop(dialogContext);
              },
            ),
        ],
      ),
    );
  }
}

/// 选项行（替代已废弃的 RadioListTile 用法）
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

class _Section extends StatelessWidget {
  final String label;

  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceXL,
        AppTokens.spaceL,
        AppTokens.spaceXL,
        AppTokens.spaceS,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(AppTokens.radiusS),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: trailing ??
          (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      onTap: onTap,
    );
  }
}
