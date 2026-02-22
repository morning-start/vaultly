import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/providers/webdav_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/vault_entry.dart';

/// WebDAV 同步页面
///
/// 执行上传、下载、查看同步状态
class WebDAVSyncPage extends ConsumerStatefulWidget {
  const WebDAVSyncPage({super.key});

  @override
  ConsumerState<WebDAVSyncPage> createState() => _WebDAVSyncPageState();
}

class _WebDAVSyncPageState extends ConsumerState<WebDAVSyncPage> {
  @override
  void initState() {
    super.initState();
    // 页面初始化时刷新配置状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webDAVConfigProvider.notifier).refresh();
    });
  }

  Future<void> _upload() async {
    final webDAVService = ref.read(webDAVServiceProvider);
    final syncNotifier = ref.read(syncOperationProvider.notifier);
    final configNotifier = ref.read(webDAVConfigProvider.notifier);

    syncNotifier.startSync('正在上传...');

    try {
      final vaultService = ref.read(vaultServiceProvider);

      // 获取当前保险库数据
      final entries = await vaultService.getAllEntries();
      final vaultData = {
        'version': 1,
        'exportTime': DateTime.now().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };

      await webDAVService.upload(vaultData: vaultData);

      if (!mounted) return;

      // 更新状态
      configNotifier.updateSyncTime(DateTime.now());
      configNotifier.updateRemoteBackupStatus(true);
      syncNotifier.completeSync('上传成功');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已上传到 WebDAV')),
      );
    } catch (e) {
      if (!mounted) return;
      syncNotifier.setError('上传失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('上传失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _download() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认下载'),
        content: const Text(
          '下载将覆盖本地数据，建议先上传备份当前数据。\n\n确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('继续下载'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final webDAVService = ref.read(webDAVServiceProvider);
    final syncNotifier = ref.read(syncOperationProvider.notifier);
    final configNotifier = ref.read(webDAVConfigProvider.notifier);

    syncNotifier.startSync('正在下载...');

    try {
      final data = await webDAVService.download();

      if (data == null) {
        throw Exception('下载的数据为空');
      }

      // 恢复数据到保险库
      final vaultService = ref.read(vaultServiceProvider);
      final authService = ref.read(authServiceProvider);

      // 确保加密密钥已设置
      final encryptionKey = authService.encryptionKey;
      if (encryptionKey != null) {
        vaultService.setEncryptionKey(encryptionKey);
      }

      // 清除现有数据
      final existingEntries = await vaultService.getAllEntries();
      for (final entry in existingEntries) {
        await vaultService.deleteEntry(entry.uuid);
      }

      // 导入新数据
      final entriesJson = data['entries'] as List<dynamic>?;
      int importedCount = 0;
      if (entriesJson != null) {
        for (final entryJson in entriesJson) {
          try {
            final entry = _parseEntryFromJson(entryJson as Map<String, dynamic>);
            if (entry != null) {
              await vaultService.addEntry(entry);
              importedCount++;
            }
          } catch (e) {
            // 继续导入其他条目
          }
        }
      }

      // 重新加载 Vault 以确保数据已正确写入存储
      await vaultService.loadVault();

      if (!mounted) return;

      // 更新状态
      configNotifier.updateSyncTime(DateTime.now());
      syncNotifier.completeSync('下载成功');

      // 通知 Vault 数据已变更，触发所有相关 Provider 刷新
      ref.read(vaultChangeNotifierProvider.notifier).notifyChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('数据已从 WebDAV 恢复，导入 $importedCount 条记录')),
      );
    } catch (e) {
      if (!mounted) return;
      syncNotifier.setError('下载失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '从未';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 根据类型解析条目 JSON
  ///
  /// 使用正确的子类 fromJson 方法，确保所有字段都被正确解析
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

    // 加载中显示进度指示器
    if (configState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('WebDAV 同步')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('加载中...'),
            ],
          ),
        ),
      );
    }

    // 未配置时显示配置引导
    if (!configState.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('WebDAV 同步')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('WebDAV 未配置'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.push('/webdav/config'),
                child: const Text('前往配置'),
              ),
            ],
          ),
        ),
      );
    }

    // 同步操作中显示进度
    if (syncState.isSyncing) {
      return Scaffold(
        appBar: AppBar(title: const Text('WebDAV 同步')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(syncState.statusMessage ?? '处理中...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 同步'),
        actions: [
          IconButton(
            onPressed: () => context.push('/webdav/config'),
            icon: const Icon(Icons.settings),
            tooltip: '配置',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态卡片
            _buildStatusCard(configState),
            const SizedBox(height: 24),

            // 同步操作
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '同步操作',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _upload,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('上传到云端'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: configState.hasRemoteBackup ? _download : null,
                            icon: const Icon(Icons.cloud_download),
                            label: const Text('从云端恢复'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 说明
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '使用说明',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 上传：将本地数据备份到 WebDAV 服务器\n'
                      '• 下载：从 WebDAV 服务器恢复数据到本地\n'
                      '• 数据在传输和存储过程中保持加密状态',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(WebDAVConfigState configState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: configState.hasRemoteBackup
                    ? Colors.green.withAlpha(26)
                    : Colors.blue.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                configState.hasRemoteBackup ? Icons.cloud_done : Icons.cloud,
                color: configState.hasRemoteBackup ? Colors.green : Colors.blue,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              configState.hasRemoteBackup ? '云端备份存在' : '云端备份不存在',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '最后同步: ${_formatDateTime(configState.lastSyncTime)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
