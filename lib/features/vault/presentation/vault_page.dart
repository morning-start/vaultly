import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/vault_entry.dart';
import '../domain/vault_notifier.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/theme/vaultly_colors.dart';
import '../../../features/tools/clipboard_service.dart';
import 'widgets/entry_card_widget.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_state.dart';

/// 保险库主页
///
/// 纯响应式：列表来自 [vaultNotifierProvider]（同步快照），
/// 写操作由 VaultNotifier 统一处理，页面无需手动刷新。
/// 结构：搜索栏 → 类型筛选 chips（含计数）→ 分组列表
/// （收藏置顶组 + 类型分组；搜索时扁平化按更新时间排序）。
/// AppBar 仅保留标题与锁定入口。
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

  void _navigateToAddEntry() {
    context.push('/add');
  }

  void _navigateToEntryDetail(VaultEntry entry) {
    context.push('/entry/${entry.uuid}');
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
    await vaultService.toggleFavorite(entry.uuid);
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final entries = _getFilteredEntries(vaultState.entries);
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppTokens.navBarHeight,
        title: Text('Vaultly', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).lock();
              context.go('/unlock');
            },
            tooltip: '锁定',
          ),
          const SizedBox(width: AppTokens.spaceS),
        ],
      ),
      body: _buildBody(vaultState, entries, isSearching),
      floatingActionButton: AnimatedScale(
        scale: _fabVisible ? 1 : 0,
        duration: AppTokens.animNormal,
        curve: AppTokens.easeOutBack,
        alignment: Alignment.bottomRight,
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddEntry,
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加'),
        ),
      ),
    );
  }

  Widget _buildBody(
      VaultState vaultState, List<VaultEntry> entries, bool isSearching) {
    // 加载中
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

    // 加载失败
    if (vaultState.error != null && vaultState.entries.isEmpty) {
      return ErrorState.load(
        message: '加载失败: ${vaultState.error}',
        onRetryPressed: () =>
            ref.read(vaultNotifierProvider.notifier).reload(),
      );
    }

    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceS,
            AppTokens.spaceL,
            0,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索标题或标签...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // 筛选 chips（含计数）
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceL,
              vertical: AppTokens.spaceS,
            ),
            children: [
              _buildFilterChip(
                label: '全部',
                count: vaultState.entries.length,
                selected: _selectedFilter == null,
                onTap: () => setState(() => _selectedFilter = null),
              ),
              for (final type in EntryType.values)
                if (type != EntryType.custom ||
                    vaultState.entries.any((e) => e.type == type))
                  _buildFilterChip(
                    label: _typeName(type),
                    count: vaultState.entries
                        .where((e) => e.type == type)
                        .length,
                    icon: _typeIcon(type),
                    iconColor:
                        Theme.of(context).colorScheme.entryType(type),
                    selected: _selectedFilter == type,
                    onTap: () => setState(() => _selectedFilter = type),
                  ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        // 条目列表或空状态
        Expanded(
          child: entries.isEmpty
              ? (isSearching
                  ? EmptyState.search(query: _searchQuery)
                  : EmptyState.vault(onAddPressed: _navigateToAddEntry))
              : isSearching
                  ? _buildFlatList(entries)
                  : _buildGroupedList(entries),
        ),
      ],
    );
  }

  /// 搜索结果：扁平化按更新时间排序
  Widget _buildFlatList(List<VaultEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return _EntryListView(
      entries: sorted,
      scrollController: _scrollController,
      onNavigate: _navigateToEntryDetail,
      onCopyPrimaryField: _copyPrimaryField,
      onToggleFavorite: _toggleFavorite,
    );
  }

  /// 默认视图：收藏置顶 + 类型分组
  Widget _buildGroupedList(List<VaultEntry> entries) {
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
    final typeOrder =
        EntryType.values.where((t) => grouped.containsKey(t)).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (favorites.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _GroupHeader(
              icon: Icons.star_rounded,
              color: colorScheme.favorite,
              title: '收藏',
              count: favorites.length,
            ),
          ),
          _EntrySliverList(
            entries: favorites,
            onNavigate: _navigateToEntryDetail,
            onCopyPrimaryField: _copyPrimaryField,
            onToggleFavorite: _toggleFavorite,
          ),
        ],
        for (final type in typeOrder) ...[
          SliverToBoxAdapter(
            child: _GroupHeader(
              icon: _typeIcon(type),
              color: colorScheme.entryType(type),
              title: _typeName(type),
              count: grouped[type]!.length,
            ),
          ),
          _EntrySliverList(
            entries: grouped[type]!,
            onNavigate: _navigateToEntryDetail,
            onCopyPrimaryField: _copyPrimaryField,
            onToggleFavorite: _toggleFavorite,
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  static String _typeName(EntryType type) => switch (type) {
        EntryType.login => '登录',
        EntryType.bankCard => '银行卡',
        EntryType.secureNote => '笔记',
        EntryType.identity => '身份',
        EntryType.custom => '自定义',
      };

  static IconData _typeIcon(EntryType type) => switch (type) {
        EntryType.login => Icons.key_rounded,
        EntryType.bankCard => Icons.credit_card_rounded,
        EntryType.secureNote => Icons.sticky_note_2_rounded,
        EntryType.identity => Icons.person_rounded,
        EntryType.custom => Icons.folder_rounded,
      };

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: AppTokens.spaceS),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
            ],
            Text(count > 0 || label == '全部' ? '$label $count' : label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.primary,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusStadium),
          side: BorderSide(
            color: selected
                ? colorScheme.primary.withAlpha(70)
                : colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}

/// 列表视图（搜索态，普通 ListView）
class _EntryListView extends StatelessWidget {
  final List<VaultEntry> entries;
  final ScrollController? scrollController;
  final void Function(VaultEntry) onNavigate;
  final void Function(VaultEntry) onCopyPrimaryField;
  final void Function(VaultEntry) onToggleFavorite;

  const _EntryListView({
    required this.entries,
    this.scrollController,
    required this.onNavigate,
    required this.onCopyPrimaryField,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: entries.length,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return EntryCardWidget(
          key: ValueKey(entry.uuid),
          entry: entry,
          onTap: () => onNavigate(entry),
          onCopyPrimaryField: () => onCopyPrimaryField(entry),
          onToggleFavorite: () => onToggleFavorite(entry),
        );
      },
    );
  }
}

/// 列表视图（分组态，Sliver）
class _EntrySliverList extends StatelessWidget {
  final List<VaultEntry> entries;
  final void Function(VaultEntry) onNavigate;
  final void Function(VaultEntry) onCopyPrimaryField;
  final void Function(VaultEntry) onToggleFavorite;

  const _EntrySliverList({
    required this.entries,
    required this.onNavigate,
    required this.onCopyPrimaryField,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = entries[index];
            return EntryCardWidget(
              key: ValueKey(entry.uuid),
              entry: entry,
              onTap: () => onNavigate(entry),
              onCopyPrimaryField: () => onCopyPrimaryField(entry),
              onToggleFavorite: () => onToggleFavorite(entry),
            );
          },
          childCount: entries.length,
        ),
      ),
    );
  }
}

/// 分组头
class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;

  const _GroupHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceM + AppTokens.spaceL,
        AppTokens.spaceL,
        AppTokens.spaceS,
        AppTokens.spaceM,
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppTokens.spaceS),
          Text(
            title,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTokens.spaceS),
          Text(
            '$count',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}
