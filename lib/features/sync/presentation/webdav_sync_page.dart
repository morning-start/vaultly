import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/vault/presentation/vault_providers.dart';
import 'sync_providers.dart';
import '../../../features/auth/presentation/auth_providers.dart';
import '../../../features/vault/domain/vault_entry.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';

/// WebDAV 同步页（原型 sync.html）
///
/// 状态卡（立即同步）→ 服务器 / 同步操作 / 数据安全 分组卡片
/// → 加密说明页脚。上传、下载与加密逻辑保持不变。
class WebDAVSyncPage extends ConsumerStatefulWidget {
  const WebDAVSyncPage({super.key});

  @override
  ConsumerState<WebDAVSyncPage> createState() => _WebDAVSyncPageState();
}

class _WebDAVSyncPageState extends ConsumerState<WebDAVSyncPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webDAVConfigProvider.notifier).refresh();
    });
  }

  Future<void> _upload() async {
    final webDAVService = ref.read(webDAVServiceProvider);
    final syncNotifier = ref.read(syncOperationProvider.notifier);
    final configNotifier = ref.read(webDAVConfigProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final encryptionKey = authNotifier.encryptionKey;
    if (encryptionKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('错误：未找到加密密钥')));
      return;
    }

    final config = await webDAVService.getConfig();
    final enableEncryption = config?.enableEncryption ?? true;
    final enableCompression = config?.enableCompression ?? true;

    syncNotifier.startSync(enableEncryption ? '正在加密上传...' : '正在上传...');

    try {
      final entries = ref.read(vaultNotifierProvider).entries;
      final vaultData = {
        'version': 1,
        'exportTime': DateTime.now().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };

      await webDAVService.upload(
        vaultData: vaultData,
        encryptionKey: encryptionKey,
        enableEncryption: enableEncryption,
        enableCompression: enableCompression,
      );

      if (!mounted) return;

      configNotifier.updateSyncTime(DateTime.now());
      configNotifier.updateRemoteBackupStatus(true);
      syncNotifier.completeSync('上传成功');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据已上传到 WebDAV')));
    } catch (e) {
      if (!mounted) return;
      syncNotifier.setError('上传失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  Future<void> _download() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认下载'),
        content: const Text('下载将覆盖本地数据，建议先上传备份当前数据。\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续下载'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final webDAVService = ref.read(webDAVServiceProvider);
    final syncNotifier = ref.read(syncOperationProvider.notifier);
    final configNotifier = ref.read(webDAVConfigProvider.notifier);

    final authNotifier = ref.read(authNotifierProvider.notifier);

    final encryptionKey = authNotifier.encryptionKey;
    if (encryptionKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('错误：未找到加密密钥')));
      }
      return;
    }

    final config = await webDAVService.getConfig();
    final enableEncryption = config?.enableEncryption ?? true;
    final enableCompression = config?.enableCompression ?? true;

    syncNotifier.startSync(enableEncryption ? '正在下载解密...' : '正在下载...');

    try {
      final data = await webDAVService.download(
        encryptionKey: encryptionKey,
        enableEncryption: enableEncryption,
        enableCompression: enableCompression,
      );

      if (data == null) {
        throw Exception('下载的数据为空');
      }

      // 原子替换：解析全部条目后一次性替换并持久化。
      final entriesJson = data['entries'] as List<dynamic>?;
      final importedEntries = <VaultEntry>[];
      if (entriesJson != null) {
        for (final entryJson in entriesJson) {
          try {
            final entry = _parseEntryFromJson(
              entryJson as Map<String, dynamic>,
            );
            if (entry != null) {
              importedEntries.add(entry);
            }
          } catch (e) {
            // 跳过损坏条目，继续导入其他条目
          }
        }
      }

      final vaultNotifier = ref.read(vaultNotifierProvider.notifier);
      final success = await vaultNotifier.replaceAllEntries(importedEntries);
      if (!success) {
        throw Exception(
          '恢复失败: ${ref.read(vaultNotifierProvider).error ?? '未知错误'}',
        );
      }

      if (!mounted) return;

      configNotifier.updateSyncTime(DateTime.now());
      syncNotifier.completeSync('下载成功');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据已从 WebDAV 恢复，导入 ${importedEntries.length} 条记录'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      syncNotifier.setError('下载失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '从未同步';
    final now = DateTime.now();
    final sameDay =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
    return sameDay ? '今天 $time' : '${dateTime.month}/${dateTime.day} $time';
  }

  /// 根据类型解析条目 JSON
  VaultEntry? _parseEntryFromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    if (typeStr == null) return null;

    final type = EntryType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => EntryType.custom,
    );

    switch (type) {
      case EntryType.login:
        return LoginEntry.fromJson(json);
      case EntryType.bankCard:
        return BankCardEntry.fromJson(json);
      case EntryType.secureNote:
        return SecureNoteEntry.fromJson(json);
      case EntryType.identity:
        return IdentityEntry.fromJson(json);
      case EntryType.custom:
        return VaultEntry.fromJson(json);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(webDAVConfigProvider);
    final syncState = ref.watch(syncOperationProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.bg,
      appBar: AppBar(
        title: const Text('WebDAV 同步'),
        actions: [
          IconButton(
            onPressed: () => context.push('/webdav/config'),
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: '配置',
          ),
        ],
      ),
      body: _buildBody(configState, syncState, colorScheme),
    );
  }

  Widget _buildBody(
    WebDAVConfigState configState,
    SyncOperationState syncState,
    ColorScheme colorScheme,
  ) {
    if (configState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!configState.isConfigured) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: colorScheme.textFaint),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            'WebDAV 未配置',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            '配置服务器后可跨设备同步加密保险库',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.textMuted),
          ),
          const SizedBox(height: AppTokens.spaceXL),
          FilledButton(
            onPressed: () => context.push('/webdav/config'),
            child: const Text('前往配置'),
          ),
        ],
      );
    }

    if (syncState.isSyncing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTokens.spaceL),
            Text(syncState.statusMessage ?? '处理中...'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _buildHeroCard(configState, colorScheme),
        _sectionLabel('服务器'),
        _card(colorScheme, [
          _svRow('服务器状态', configState.isConfigured ? '已连接' : '未连接'),
          _svRow('云端备份', configState.hasRemoteBackup ? '存在' : '不存在'),
          _svRow('最后同步', _formatDateTime(configState.lastSyncTime)),
          _svRow('应用密码', '已存入系统安全区'),
        ]),
        _sectionLabel('同步操作'),
        _card(colorScheme, [
          _actionRow(colorScheme, '上传到云端', onTap: _upload),
          _actionRow(
            colorScheme,
            '从云端恢复',
            trailingText: configState.hasRemoteBackup ? null : '无备份',
            onTap: configState.hasRemoteBackup ? _download : null,
          ),
        ]),
        _sectionLabel('数据安全'),
        _card(colorScheme, [
          _svRow(
            '端到端加密',
            'AES-256-GCM',
            mono: true,
            valueColor: colorScheme.accent,
          ),
          _svRow('完整性校验', 'SHA-256', mono: true),
          _svRow('冲突处理', '保留较新版本'),
        ]),
        const SizedBox(height: AppTokens.spaceL),
        Text(
          '服务器上始终只保存加密后的数据，\n主密钥不会离开这台设备。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.8,
            color: colorScheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    WebDAVConfigState configState,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
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
              Icons.cloud_done_outlined,
              size: 26,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('自动同步已开启', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${configState.hasRemoteBackup ? '云端备份存在' : '等待首次备份'} · '
                  '${_formatDateTime(configState.lastSyncTime)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colorScheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceS),
          FilledButton(
            onPressed: _upload,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('立即同步'),
          ),
        ],
      ),
    );
  }

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

  Widget _card(ColorScheme colorScheme, List<Widget> children) {
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

  Widget _svRow(
    String label,
    String value, {
    bool mono = false,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colorScheme.textMuted),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: mono ? AppTokens.monoFamily : null,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    ColorScheme colorScheme,
    String title, {
    VoidCallback? onTap,
    String? trailingText,
  }) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: onTap == null
                    ? colorScheme.textFaint
                    : colorScheme.onSurface,
              ),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(fontSize: 13, color: colorScheme.textMuted),
            ),
          if (onTap != null) ...[
            const SizedBox(width: AppTokens.spaceXS),
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
