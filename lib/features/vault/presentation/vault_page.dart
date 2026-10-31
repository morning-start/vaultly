import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../sync/presentation/sync_providers.dart';
import 'package:vaultly_core/vaultly_core.dart';
import '../domain/vault_notifier.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../../features/tools/clipboard_service.dart';
import 'widgets/entry_card_widget.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_state.dart';

/// 保险库主页（原型 vault.html）
///
/// 纯响应式：列表来自 [vaultNotifierProvider]（同步快照），
/// 写操作由 VaultNotifier 统一处理，页面无需手动刷新。
///
/// 结构：大标题头部（条目数 + 同步状态 + 同步/锁定入口）
/// → 搜索框 → 类型筛选 chips → 分组卡片列表（收藏置顶 + 类型分组）。
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  EntryType? _selectedFilter;
  bool _fabVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    if (delta.abs() < 4) return;

    final shouldShow = delta < 0 || offset <= 0;
    if (shouldShow != _fabVisible) {
      setState(() => _fabVisible = shouldShow);
    }
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<VaultEntry> _getFilteredEntries(List<VaultEntry> entries) {
    var filtered = entries.toList();

    if (_selectedFilter != null) {
      filtered = filtered.where((e) => e.type == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        if (e.title.toLowerCase().contains(query)) return true;
        if (e.tags.any((t) => t.toLowerCase().contains(query))) return true;
        return false;
      }).toList();
    }

    return filtered;
  }

  void _navigateToAddEntry() => context.push('/add');

  void _navigateToEntryDetail(VaultEntry entry) =>
      context.push('/entry/${entry.id}');

  void _lock() {
    ref.read(authNotifierProvider.notifier).lock();
    context.go('/unlock');
  }

  Future<void> _copyPrimaryField(VaultEntry entry) async {
    final value = switch (entry) {
      LoginEntry l when (l.password ?? '').isNotEmpty => l.password,
      BankCardEntry b when (b.cardNumber ?? '').isNotEmpty =>
        b.cardNumber?.replaceAll(' ', ''),
      _ => null,
    };
    if (value == null) {
      if (mounted) AppToast.show(context, '该条目没有可复制的机密字段');
      return;
    }
    await ClipboardService().copySensitive(value, label: entry.title);
    if (mounted) {
      AppToast.show(context, '${entry.title} 已复制（30 秒后自动清除）');
    }
  }

  Future<void> _toggleFavorite(VaultEntry entry) async {
    final vaultService = ref.read(vaultServiceProvider);
    await vaultService.toggleFavorite(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final syncState = ref.watch(webDAVConfigProvider);
    final entries = _getFilteredEntries(vaultState.entries);
    final isSearching = _searchQuery.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.bg,
      body: SafeArea(
        bottom: false,
        child: _buildBody(vaultState, syncState, entries, isSearching),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildFab(colorScheme),
    );
  }

  Widget _buildFab(ColorScheme colorScheme) {
    return AnimatedScale(
      scale: _fabVisible ? 1 : 0,
      duration: AppTokens.animNormal,
      curve: AppTokens.easeOutBack,
      alignment: Alignment.bottomRight,
      child: Container(
        width: AppTokens.fabSize,
        height: AppTokens.fabSize,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(115),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusL),
            onTap: _navigateToAddEntry,
            child: Semantics(
              button: true,
              label: '添加条目',
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 主数据损坏、已从写前备份恢复时的告知条
  ///
  /// 必须明确告知：恢复出来的是「上一次成功写入」的内容，
  /// 最后一次修改已经丢了，用户需要自己核对。
  Widget _buildRecoveryNotice() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(AppTokens.spaceM),
      decoration: BoxDecoration(
        color: colorScheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, size: 18, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已从写前备份恢复',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '本地数据主副本损坏，已回退到上一次保存的版本。'
                  '最后一次修改的内容可能丢失，请核对后再继续操作。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: colorScheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    VaultState vaultState,
    WebDAVConfigState syncState,
    List<VaultEntry> entries,
    bool isSearching,
  ) {
    if (!vaultState.isLoaded) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppTokens.spaceL),
            Text('加载中...'),
          ],
        ),
      );
    }

    if (vaultState.error != null && vaultState.entries.isEmpty) {
      return ErrorState.load(
        message: '加载失败: ${vaultState.error}',
        onRetryPressed: () => ref.read(vaultNotifierProvider.notifier).reload(),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (vaultState.recoveredFromBackup)
          SliverToBoxAdapter(child: _buildRecoveryNotice()),
        SliverToBoxAdapter(child: _buildHeader(vaultState, syncState)),
        SliverToBoxAdapter(child: _buildSearch()),
        SliverToBoxAdapter(child: _buildFilterChips(vaultState)),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: isSearching
                ? EmptyState.search(query: _searchQuery)
                : EmptyState.vault(onAddPressed: _navigateToAddEntry),
          )
        else if (isSearching)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _EntryGroup(
                entries: _sortForSearch(entries),
                onNavigate: _navigateToEntryDetail,
                onCopyPrimaryField: _copyPrimaryField,
                onToggleFavorite: _toggleFavorite,
              ),
            ),
          )
        else
          ..._buildGroupedSections(entries),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 120 + MediaQuery.viewPaddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(VaultState vaultState, WebDAVConfigState syncState) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final synced = syncState.isConfigured && syncState.lastSyncTime != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('保险库', style: textTheme.displayLarge),
                const SizedBox(height: 2),
                Text(
                  '${vaultState.entries.length} 个条目${_syncLabel(syncState)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _HeaderAction(
            icon: Icons.cloud_done_outlined,
            tooltip: '同步',
            showDot: synced,
            onTap: () => context.push('/webdav'),
          ),
          _HeaderAction(
            icon: Icons.lock_outline_rounded,
            tooltip: '立即锁定',
            onTap: _lock,
          ),
        ],
      ),
    );
  }

  String _syncLabel(WebDAVConfigState syncState) {
    if (!syncState.isConfigured) return '';
    final last = syncState.lastSyncTime;
    if (last == null) return ' · 待首次同步';
    final now = DateTime.now();
    final sameDay =
        last.year == now.year && last.month == now.month && last.day == now.day;
    final time =
        '${last.hour.toString().padLeft(2, '0')}:'
        '${last.minute.toString().padLeft(2, '0')}';
    return sameDay
        ? ' · 今天 $time 已同步'
        : ' · ${last.month}/${last.day} $time 已同步';
  }

  Widget _buildSearch() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSearching = _searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SizedBox(
        height: AppTokens.searchHeight,
        child: TextField(
          controller: _searchController,
          style: Theme.of(context).textTheme.bodyLarge,
          textInputAction: TextInputAction.search,
          cursorColor: colorScheme.primary,
          decoration: InputDecoration(
            hintText: '搜索名称、用户名或网址',
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: colorScheme.textFaint,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 20,
            ),
            suffixIcon: isSearching
                ? IconButton(
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: colorScheme.textFaint,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 20,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildFilterChips(VaultState vaultState) {
    final chips = <_ChipData>[
      _ChipData('全部', vaultState.entries.length, null),
      for (final type in EntryType.values)
        if (type != EntryType.custom ||
            vaultState.entries.any((e) => e.type == type))
          _ChipData(
            _typeName(type),
            vaultState.entries.where((e) => e.type == type).length,
            type,
          ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return _FilterChip(
            label: chip.label,
            count: chip.count,
            selected: _selectedFilter == chip.type,
            onTap: () => setState(() => _selectedFilter = chip.type),
          );
        },
      ),
    );
  }

  List<VaultEntry> _sortForSearch(List<VaultEntry> entries) {
    return entries.toList()..sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  /// 默认视图：收藏置顶 + 类型分组
  List<Widget> _buildGroupedSections(List<VaultEntry> entries) {
    final favorites = entries.where((e) => e.isFavorite).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final rest = entries.where((e) => !e.isFavorite).toList();

    final grouped = <EntryType, List<VaultEntry>>{};
    for (final entry in rest) {
      grouped.putIfAbsent(entry.type, () => []).add(entry);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final typeOrder = EntryType.values
        .where((t) => grouped.containsKey(t))
        .toList();
    final colorScheme = Theme.of(context).colorScheme;

    return [
      if (favorites.isNotEmpty)
        _buildSection(
          entries: favorites,
          title: '收藏',
          icon: Icons.star_rounded,
          iconColor: colorScheme.favorite,
        ),
      for (final type in typeOrder)
        _buildSection(entries: grouped[type]!, title: _typeName(type)),
    ];
  }

  Widget _buildSection({
    required List<VaultEntry> entries,
    required String title,
    IconData? icon,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 10),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: colorScheme.textMuted,
                    ),
                  ),
                  const Spacer(),
                  if (icon != null) Icon(icon, size: 14, color: iconColor),
                ],
              ),
            ),
            _EntryGroup(
              entries: entries,
              onNavigate: _navigateToEntryDetail,
              onCopyPrimaryField: _copyPrimaryField,
              onToggleFavorite: _toggleFavorite,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _typeName(EntryType type) => switch (type) {
    EntryType.login => '登录',
    EntryType.bankCard => '银行卡',
    EntryType.secureNote => '笔记',
    EntryType.identity => '身份',
    EntryType.custom => '自定义',
  };
}

/// 筛选 chip 数据
class _ChipData {
  const _ChipData(this.label, this.count, this.type);

  final String label;
  final int count;
  final EntryType? type;
}

/// 胶囊筛选 chip（原型 `.chip`）
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.primary : colorScheme.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTokens.animFast,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusStadium),
          border: Border.all(
            color: selected ? Colors.transparent : colorScheme.hairlineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foreground.withAlpha(190),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 头部图标按钮（44x44，可带同步状态点）
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool showDot;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22, color: colorScheme.onSurface),
              if (showDot)
                Positioned(
                  right: 8,
                  bottom: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colorScheme.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.bg, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个分组卡片：surface 底 + line 描边 + 行间分隔线
class _EntryGroup extends StatelessWidget {
  final List<VaultEntry> entries;
  final void Function(VaultEntry) onNavigate;
  final void Function(VaultEntry) onCopyPrimaryField;
  final void Function(VaultEntry) onToggleFavorite;

  const _EntryGroup({
    required this.entries,
    required this.onNavigate,
    required this.onCopyPrimaryField,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i > 0) {
        children.add(
          Divider(height: 1, thickness: 1, color: colorScheme.hairline),
        );
      }
      children.add(
        EntryCardWidget(
          key: ValueKey(entry.id),
          entry: entry,
          onTap: () => onNavigate(entry),
          onCopyPrimaryField: () => onCopyPrimaryField(entry),
          onToggleFavorite: () => onToggleFavorite(entry),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(color: colorScheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
