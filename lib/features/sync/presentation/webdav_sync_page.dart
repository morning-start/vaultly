import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/vault/presentation/vault_providers.dart';
import 'sync_providers.dart';
import '../../../features/auth/presentation/auth_providers.dart';
import '../../../features/vault/domain/vault_entry.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../data/webdav_client.dart' show RemoteBackupFormats, WebDAVException;
import '../../auth/data/crypto_service.dart' show KdfParams;
import '../domain/vault_merge.dart';

/// 每次操作的执行方式
enum SyncApplyMode {
  /// 兼容模式：与云端/本地合并，按更新时间取较新者
  merge,

  /// 覆盖模式：完全覆盖目标端数据
  overwrite,
}

/// 一次操作的选择结果
class _SyncPlan {
  const _SyncPlan({required this.mode});

  final SyncApplyMode mode;
}

/// WebDAV 同步页（原型 sync.html）
///
/// 上传与下载是两个独立动作；每次操作前弹出面板选择处理模式：
/// - 处理模式：兼容（合并） / 覆盖
///
/// 传输安全策略：AES-256-GCM 加密与 GZIP 压缩固定启用，
/// 不提供关闭入口，避免误操作导致明文上云。
class WebDAVSyncPage extends ConsumerStatefulWidget {
  const WebDAVSyncPage({super.key});

  @override
  ConsumerState<WebDAVSyncPage> createState() => _WebDAVSyncPageState();
}

class _WebDAVSyncPageState extends ConsumerState<WebDAVSyncPage> {
  /// 云端备份是否由「另一套密钥体系」上传（改过主密码后为 true）
  bool _remoteBackupStale = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(webDAVConfigProvider.notifier).refresh();
      await _refreshBackupFreshness();
    });
  }

  /// 重新判断云端备份是否还由当前主密码加密
  ///
  /// 判据是「最近一次上传记录的密钥指纹」与当前指纹是否一致。指纹只在
  /// 成功上传后写入、在清除 WebDAV 配置时删除，因此这个判定不依赖网络
  /// 查询，是即时且确定的（不必等 hasRemoteBackup 那次异步探测）。
  Future<void> _refreshBackupFreshness() async {
    try {
      final currentTag =
          await ref.read(authNotifierProvider.notifier).currentKeyTag();
      final stale = await ref
          .read(webDAVServiceProvider)
          .isRemoteBackupStale(currentKeyTag: currentTag);

      if (mounted) setState(() => _remoteBackupStale = stale);
    } catch (e) {
      debugPrint('WebDAV: 检查备份新鲜度失败: $e');
    }
  }

  // ==================== 操作入口 ====================

  Future<void> _handleUpload() async {
    final plan = await _showPlanSheet(isUpload: true);
    if (plan == null || !mounted) return;

    if (plan.mode == SyncApplyMode.overwrite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmDialog(
          title: '覆盖云端备份？',
          content:
              '覆盖模式会用本地数据完全替换云端文件，'
              '云端独有的条目将被删除。此操作不可撤销。',
          confirmLabel: '继续上传',
          isDangerous: true,
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _upload(plan);
  }

  Future<void> _handleDownload() async {
    final plan = await _showPlanSheet(isUpload: false);
    if (plan == null || !mounted) return;

    if (plan.mode == SyncApplyMode.overwrite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmDialog(
          title: '覆盖本地数据？',
          content:
              '覆盖模式会用云端数据完全替换本地保险库，'
              '尚未上传的本地条目将丢失。此操作不可撤销。',
          confirmLabel: '继续恢复',
          isDangerous: true,
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _download(plan);
  }

  // ==================== 解密密钥 ====================

  /// 按备份文件头里的 KDF 参数解析出解密密钥。
  ///
  /// **注意用的是 `backupKey`（主密码派生），不是 `encryptionKey`（本地 DEK）**：
  /// 备份必须能被其他设备用同一个主密码解开，因此不能用只属于本机的 DEK。
  ///
  /// 三种情况：
  /// 1. 文件头与本机参数一致（本机上传的备份）→ 直接用本机派生密钥，
  ///    不需要明文口令，生物识别解锁下也能恢复；
  /// 2. 文件头不同（备份来自另一台设备）→ 必须用「主密码 + 文件里的盐值」
  ///    重新派生。这正是换手机后能解开云端备份的关键；
  /// 3. 旧格式备份没有文件头（盐值只存在于原设备）→ 退回本机派生密钥，
  ///    只有原设备能解开。
  Future<Uint8List> _resolveBackupKey(KdfParams? kdfFromFile) async {
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final backupKey = authNotifier.backupKey;
    if (backupKey == null) {
      throw WebDAVException('未找到主密钥，请重新解锁');
    }

    if (kdfFromFile == null) {
      return backupKey;
    }

    final localKdf = await authNotifier.currentKdfParams();
    if (localKdf.matches(kdfFromFile)) {
      return backupKey;
    }

    final password = authNotifier.masterPassword;
    if (password == null) {
      throw WebDAVException(
        '这份备份来自另一台设备，需要用主密码解密。'
        '请锁定后改用主密码解锁，再重试恢复。',
      );
    }
    return authNotifier.deriveVaultKey(password, kdfFromFile);
  }

  // ==================== 上传 ====================

  Future<void> _upload(_SyncPlan plan) async {
    final webDAVService = ref.read(webDAVServiceProvider);
    final syncNotifier = ref.read(syncOperationProvider.notifier);
    final configNotifier = ref.read(webDAVConfigProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    // 上传同样用主密码派生密钥（不是本地 DEK），保证其他设备能解开
    final encryptionKey = authNotifier.backupKey;
    if (encryptionKey == null) {
      _toast('未找到主密钥，请重新解锁');
      return;
    }

    final kdfParams = await authNotifier.currentKdfParams();
    final keyTag = await authNotifier.currentKeyTag();

    var entries = ref.read(vaultNotifierProvider).entries;
    VaultMergeResult? mergeResult;

    syncNotifier.startSync('正在合并并加密上传...');

    try {
      if (plan.mode == SyncApplyMode.merge) {
        // 兼容模式：先拉取云端，合并后再整体上传，并同步回本地
        try {
          final remoteBackup = await webDAVService.download(
            keyResolver: _resolveBackupKey,
          );
          final remoteEntries = _parseEntries(remoteBackup.data);
          if (remoteEntries != null && remoteEntries.isNotEmpty) {
            mergeResult = mergeVaultEntries(
              local: entries,
              remote: remoteEntries,
            );
            entries = mergeResult.entries;
          }
        } catch (e) {
          // 云端还没有该格式的备份：按首次上传处理
          debugPrint('WebDAV merge skipped: $e');
        }
      }

      await webDAVService.upload(
        vaultData: _vaultData(entries),
        encryptionKey: encryptionKey,
        kdfParams: kdfParams,
        keyTag: keyTag,
      );

      // 合并结果回写本地，保持两端一致
      if (mergeResult != null && mergeResult.hasRemoteChanges) {
        await ref
            .read(vaultNotifierProvider.notifier)
            .replaceAllEntries(entries);
      }

      if (!mounted) return;

      configNotifier.updateSyncTime(DateTime.now());
      configNotifier.updateRemoteBackupStatus(true);
      syncNotifier.completeSync('上传成功');

      // 上传用的就是当前主密码，备份新鲜度重新判定
      await _refreshBackupFreshness();
      if (!mounted) return;

      final detail = mergeResult == null
          ? '${entries.length} 条'
          : mergeResult.summary;
      _toast('已上传到云端 · $detail');
    } catch (e) {
      if (!mounted) return;
      // WebDAVException 自带用户可读文案（含上下文），不再重复加「上传失败」前缀
      final message = e is WebDAVException ? e.message : '上传失败: $e';
      syncNotifier.setError(message);
      _toast(message);
    }
  }

  // ==================== 下载 ====================

  Future<void> _download(_SyncPlan plan) async {
    final webDAVService = ref.read(webDAVServiceProvider);
    final syncNotifier = ref.read(syncOperationProvider.notifier);
    final configNotifier = ref.read(webDAVConfigProvider.notifier);

    syncNotifier.startSync('正在下载并解密...');

    try {
      final backup = await webDAVService.download(
        keyResolver: _resolveBackupKey,
      );

      final remoteEntries = _parseEntries(backup.data);
      if (remoteEntries == null) {
        throw Exception('下载的数据为空或格式不正确');
      }

      final localEntries = ref.read(vaultNotifierProvider).entries;
      final vaultNotifier = ref.read(vaultNotifierProvider.notifier);

      String message;
      List<VaultEntry> target;
      if (plan.mode == SyncApplyMode.merge) {
        final merged = mergeVaultEntries(
          local: localEntries,
          remote: remoteEntries,
        );
        target = merged.entries;
        message = '合并完成 · ${merged.summary}';
      } else {
        target = remoteEntries;
        message = '已恢复 ${remoteEntries.length} 条记录';
      }

      // 旧格式备份没有文件头，只能在本机解开；提示用户重新上传一次，
      // 生成可跨设备恢复的新格式备份。
      if (backup.legacyFormat) {
        message = '$message · 旧格式备份，建议重新上传以支持跨设备恢复';
      }

      final success = await vaultNotifier.replaceAllEntries(target);
      if (!success) {
        throw Exception(
          '恢复失败: ${ref.read(vaultNotifierProvider).error ?? '未知错误'}',
        );
      }

      if (!mounted) return;

      configNotifier.updateSyncTime(DateTime.now());
      syncNotifier.completeSync('下载成功');
      _toast(message);
    } catch (e) {
      if (!mounted) return;
      // WebDAVException 自带用户可读文案（含上下文），不再重复加「下载失败」前缀
      final message = e is WebDAVException ? e.message : '下载失败: $e';
      syncNotifier.setError(message);
      _toast(message);
    }
  }

  // ==================== 操作面板 ====================

  Future<_SyncPlan?> _showPlanSheet({required bool isUpload}) async {
    RemoteBackupFormats formats = const RemoteBackupFormats();
    if (!isUpload) {
      formats = await ref.read(webDAVServiceProvider).listRemoteBackups();
      if (!mounted) return null;
      // 传输固定加密：只恢复加密备份
      if (!formats.hasEncrypted) {
        _toast(
          formats.hasPlain
              ? '云端只有历史明文备份；请先「合并并上传」生成加密备份'
              : '云端还没有加密备份，请先上传',
        );
        return null;
      }
    }

    var mode = SyncApplyMode.merge;

    final result = await showModalBottomSheet<_SyncPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isUpload ? '上传到云端' : '从云端恢复',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUpload ? '云端文件会被本次上传结果替换或合并' : '本地保险库会被本次恢复结果覆盖或合并',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sheetLabel('处理模式', colorScheme),
                    _ModeOption(
                      icon: Icons.merge_rounded,
                      title: '兼容（合并）',
                      subtitle: isUpload
                          ? '先合并云端较新的条目，再整体上传'
                          : '保留本地条目，云端较新的条目覆盖同一条目',
                      selected: mode == SyncApplyMode.merge,
                      onTap: () =>
                          setSheetState(() => mode = SyncApplyMode.merge),
                    ),
                    const SizedBox(height: 10),
                    _ModeOption(
                      icon: Icons.swap_vert_rounded,
                      title: '覆盖',
                      subtitle: isUpload ? '云端数据被本地完全替换' : '本地数据被云端完全替换',
                      selected: mode == SyncApplyMode.overwrite,
                      danger: true,
                      onTap: () =>
                          setSheetState(() => mode = SyncApplyMode.overwrite),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceCard,
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '传输固定使用 AES-256-GCM 加密 + GZIP 压缩，密钥派生参数随备份保存，'
                              '换设备后用同一个主密码即可恢复',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _SyncPlan(mode: mode),
                      ),
                      style: mode == SyncApplyMode.overwrite
                          ? FilledButton.styleFrom(
                              backgroundColor: colorScheme.dangerSoft,
                              foregroundColor: colorScheme.error,
                            )
                          : null,
                      child: Text(
                        isUpload
                            ? (mode == SyncApplyMode.overwrite
                                  ? '覆盖云端'
                                  : '合并并上传')
                            : (mode == SyncApplyMode.overwrite
                                  ? '覆盖本地'
                                  : '合并到本地'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '每次操作都可单独选择处理模式，配置页只保存服务器连接信息。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colorScheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Widget _sheetLabel(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: colorScheme.textMuted,
        ),
      ),
    );
  }

  // ==================== 页面 ====================

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
            tooltip: '连接配置',
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
        if (_remoteBackupStale) _buildStaleBackupNotice(colorScheme),
        _sectionLabel('服务器'),
        _card(colorScheme, [
          _svRow('服务器状态', configState.isConfigured ? '已连接' : '未连接'),
          _svRow('云端备份', configState.hasRemoteBackup ? '存在' : '不存在'),
          _svRow('最后同步', _formatDateTime(configState.lastSyncTime)),
          _svRow('应用密码', '已存入系统安全区'),
        ]),
        _sectionLabel('手动操作'),
        _card(colorScheme, [
          _actionRow(
            colorScheme,
            '上传到云端',
            trailingText: '可选合并或覆盖',
            onTap: _handleUpload,
          ),
          _actionRow(
            colorScheme,
            '从云端恢复',
            trailingText: configState.hasRemoteBackup ? '可选合并或覆盖' : '无备份',
            onTap: configState.hasRemoteBackup ? _handleDownload : null,
          ),
        ]),
        _sectionLabel('数据安全'),
        _card(colorScheme, [
          _svRow(
            '加密算法',
            'AES-256-GCM',
            mono: true,
            valueColor: colorScheme.accent,
          ),
          _svRow('完整性校验', 'SHA-256', mono: true),
          _svRow('合并策略', '按更新时间取较新'),
        ]),
        const SizedBox(height: AppTokens.spaceL),
        Text(
          '服务器上只保存密文和公开的密钥派生参数，\n'
          '密钥永远不会上传；任何设备用同一个主密码都能解开。',
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

  /// 云端备份过期提示：改过主密码后，云端那份只有旧密码能解开
  ///
  /// 这里必须主动提示，否则用户会以为「当前主密码一定能恢复」，
  /// 等到真需要恢复时才发现打不开。
  Widget _buildStaleBackupNotice(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: AppTokens.spaceM),
      padding: const EdgeInsets.all(AppTokens.spaceM),
      decoration: BoxDecoration(
        color: colorScheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '云端备份还是旧主密码加密的',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '主密码改过之后，云端那份备份需要用旧密码才能解开。'
            '重新上传一次，它就会用当前主密码加密。',
            style: TextStyle(fontSize: 12, height: 1.6, color: colorScheme.textMuted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _handleUpload,
              child: const Text('用当前主密码重新上传'),
            ),
          ),
        ],
      ),
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
                Text(
                  'WebDAV 已连接',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${configState.hasRemoteBackup ? '云端备份存在' : '等待首次上传'} · '
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
            onPressed: _handleUpload,
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
            child: const Text('上传'),
          ),
        ],
      ),
    );
  }

  // ==================== 数据转换 ====================

  Map<String, dynamic> _vaultData(List<VaultEntry> entries) => {
    'version': 1,
    'exportTime': DateTime.now().toIso8601String(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  List<VaultEntry>? _parseEntries(Map<String, dynamic>? data) {
    if (data == null) return null;
    final list = data['entries'] as List<dynamic>?;
    if (list == null) return null;

    final entries = <VaultEntry>[];
    for (final json in list) {
      try {
        final entry = _parseEntryFromJson(json as Map<String, dynamic>);
        if (entry != null) entries.add(entry);
      } catch (e) {
        // 跳过损坏条目，继续解析其他条目
      }
    }
    return entries;
  }

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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              style: TextStyle(fontSize: 12, color: colorScheme.textMuted),
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

/// 操作面板中的模式选项
class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = danger ? colorScheme.error : colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      child: AnimatedContainer(
        duration: AppTokens.animFast,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(36) : colorScheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          border: Border.all(
            color: selected ? accent.withAlpha(120) : colorScheme.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? accent : colorScheme.textMuted,
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? accent : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: colorScheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.spaceS),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? accent : colorScheme.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
