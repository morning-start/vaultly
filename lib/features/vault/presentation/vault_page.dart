import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/vault_entry.dart';
import '../domain/vault_notifier.dart';
import 'vault_providers.dart';
import '../../../ui/theme/tokens.dart';
import 'widgets/entry_card_widget.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_state.dart';

/// 保险库主页
///
/// 纯响应式：列表来自 [vaultEntriesProvider]（同步快照），
/// 写操作由 VaultNotifier 统一处理，页面无需手动刷新。
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
    var filtered = entries;

    if (_selectedFilter != null) {
      filtered = filtered.where((e) => e.type == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        if (e.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return true;
        }
        if (e.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()))) {
          return true;
        }
        return false;
      }).toList();
    }

    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return filtered;
  }

  void _navigateToAddEntry() {
    context.push('/add');
  }

  void _navigateToEntryDetail(VaultEntry entry) {
    context.push('/entry/${entry.uuid}');
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final entries = _getFilteredEntries(vaultState.entries);

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            toolbarHeight: AppTokens.navBarHeight,
            title: Text(
              'Vaultly',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.cloud_outlined),
              onPressed: () => context.push('/webdav'),
              tooltip: '云同步',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.fingerprint_rounded),
                onPressed: () => context.push('/settings/biometric'),
                tooltip: '生物识别设置',
              ),
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded),
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).lock();
                  context.go('/unlock');
                },
                tooltip: '锁定',
              ),
            ],
          ),
        ],
        body: _buildBody(vaultState, entries),
      ),
      floatingActionButton: AnimatedScale(
        scale: _fabVisible ? 1 : 0,
        duration: AppTokens.animNormal,
        curve: AppTokens.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusXL),
            gradient: AppTokens.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withAlpha(100),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _navigateToAddEntry,
            backgroundColor: Colors.transparent,
            elevation: 0,
            hoverColor: Colors.transparent,
            highlightElevation: 0,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '添加',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(VaultState vaultState, List<VaultEntry> entries) {
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
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusL),
              border: Border.all(
                color: _searchQuery.isNotEmpty
                    ? Theme.of(context).colorScheme.primary.withAlpha(80)
                    : Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: AppTokens.spaceL),
                Icon(
                  Icons.search_rounded,
                  color: _searchQuery.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: AppTokens.spaceM),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索条目...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: AppTokens.spaceM,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
        ),
        // 筛选器
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
                icon: Icons.dashboard_rounded,
                selected: _selectedFilter == null,
                onTap: () => setState(() => _selectedFilter = null),
              ),
              _buildFilterChip(
                label: '登录',
                icon: Icons.login_rounded,
                selected: _selectedFilter == EntryType.login,
                onTap: () => setState(() => _selectedFilter = EntryType.login),
              ),
              _buildFilterChip(
                label: '银行卡',
                icon: Icons.credit_card_rounded,
                selected: _selectedFilter == EntryType.bankCard,
                onTap: () =>
                    setState(() => _selectedFilter = EntryType.bankCard),
              ),
              _buildFilterChip(
                label: '笔记',
                icon: Icons.sticky_note_2_rounded,
                selected: _selectedFilter == EntryType.secureNote,
                onTap: () =>
                    setState(() => _selectedFilter = EntryType.secureNote),
              ),
              _buildFilterChip(
                label: '身份',
                icon: Icons.person_rounded,
                selected: _selectedFilter == EntryType.identity,
                onTap: () =>
                    setState(() => _selectedFilter = EntryType.identity),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        // 条目列表或空状态
        Expanded(
          child: entries.isEmpty
              ? (_searchQuery.isNotEmpty
                  ? EmptyState.search(query: _searchQuery)
                  : EmptyState.vault(onAddPressed: _navigateToAddEntry))
              : ListView.builder(
                  itemCount: entries.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceL,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(entry.uuid),
                      tween: Tween(begin: 0, end: 1),
                      duration: AppTokens.animNormal,
                      curve: AppTokens.easeOutQuart,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            AppTokens.spaceS * (1 - value),
                          ),
                          child: child,
                        ),
                      ),
                      child: EntryCardWidget(
                        entry: entry,
                        onTap: () => _navigateToEntryDetail(entry),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: AppTokens.spaceS),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(icon, size: 16),
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.primary,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: BorderSide(
            color: selected
                ? colorScheme.primary.withAlpha(60)
                : colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
      ),
    );
  }
}
