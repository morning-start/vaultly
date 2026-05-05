import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/entry_card_widget.dart';
import '../widgets/empty_state.dart';
import 'add_entry_page.dart';
import 'entry_detail_page.dart';

class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  EntryType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _initializeVault();
  }

  Future<void> _initializeVault() async {
    final vaultService = ref.read(vaultServiceProvider);
    final authService = ref.read(authServiceProvider);

    final encryptionKey = authService.encryptionKey;
    if (encryptionKey == null) {
      return;
    }

    vaultService.setEncryptionKey(encryptionKey);

    try {
      await vaultService.loadVault();
      ref.read(vaultChangeNotifierProvider.notifier).notifyChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载保险库失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultEntry> _getFilteredEntries(List<VaultEntry> entries) {
    var filtered = entries.toList();

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

  void _navigateToAddEntry() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEntryPage()),
    );
    if (mounted) {
      ref.read(vaultChangeNotifierProvider.notifier).notifyChanged();
    }
  }

  void _navigateToEntryDetail(VaultEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryDetailPage(entryId: entry.uuid),
      ),
    );
    if (mounted) {
      ref.read(vaultChangeNotifierProvider.notifier).notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vaultEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaultly'),
        leading: IconButton(
          icon: const Icon(Icons.cloud_outlined),
          onPressed: () => context.push('/webdav'),
          tooltip: '云同步',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint),
            onPressed: () => context.push('/settings/biometric'),
            tooltip: '生物识别设置',
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).lock();
              context.go('/unlock');
            },
            tooltip: '锁定',
          ),
        ],
      ),
      body: entriesAsync.when(
        data: (entries) {
          final filteredEntries = _getFilteredEntries(entries);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索条目...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('全部'),
                      selected: _selectedFilter == null,
                      onSelected: (_) {
                        setState(() => _selectedFilter = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('登录'),
                      selected: _selectedFilter == EntryType.login,
                      onSelected: (_) {
                        setState(() => _selectedFilter = EntryType.login);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('银行卡'),
                      selected: _selectedFilter == EntryType.bankCard,
                      onSelected: (_) {
                        setState(() => _selectedFilter = EntryType.bankCard);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('笔记'),
                      selected: _selectedFilter == EntryType.secureNote,
                      onSelected: (_) {
                        setState(() => _selectedFilter = EntryType.secureNote);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('身份'),
                      selected: _selectedFilter == EntryType.identity,
                      onSelected: (_) {
                        setState(() => _selectedFilter = EntryType.identity);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: filteredEntries.isEmpty
                    ? EmptyState(
                        icon: _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
                        title: _searchQuery.isNotEmpty ? '未找到匹配的条目' : '暂无条目',
                        subtitle: _searchQuery.isNotEmpty
                            ? '尝试其他搜索词'
                            : '点击下方按钮添加您的第一个条目',
                      )
                    : ListView.builder(
                        itemCount: filteredEntries.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final entry = filteredEntries[index];
                          return EntryCardWidget(
                            entry: entry,
                            onTap: () => _navigateToEntryDetail(entry),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('加载中...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败: $error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(vaultEntriesProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddEntry,
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
    );
  }
}
