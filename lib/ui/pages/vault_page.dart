import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'add_entry_page.dart';
import 'entry_detail_page.dart';

/// 保险库主页
///
/// 显示所有条目，支持搜索、筛选、添加新条目
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
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final vaultService = ref.read(vaultServiceProvider);
    final authService = ref.read(authServiceProvider);
    
    // 设置加密密钥
    final encryptionKey = authService.encryptionKey;
    if (encryptionKey == null) {
      // 如果加密密钥为空，说明用户未解锁
      // 路由守卫会自动处理重定向，这里直接返回
      return;
    }
    
    vaultService.setEncryptionKey(encryptionKey);
    
    try {
      await vaultService.loadVault();
    } catch (e) {
      // 加载失败时显示错误
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载保险库失败: $e')),
        );
      }
    }
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultEntry> _getFilteredEntries() {
    final vaultService = ref.read(vaultServiceProvider);
    // 创建可变副本，因为 getAllEntries() 返回的是不可修改列表
    var entries = vaultService.getAllEntries().toList();

    if (_selectedFilter != null) {
      entries = entries.where((e) => e.type == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      entries = vaultService.searchEntries(_searchQuery).toList();
      if (_selectedFilter != null) {
        entries = entries.where((e) => e.type == _selectedFilter).toList();
      }
    }

    // 按收藏和时间排序
    entries.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return entries;
  }

  void _navigateToAddEntry() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEntryPage()),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToEntryDetail(VaultEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryDetailPage(entryId: entry.uuid),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _getFilteredEntries();

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
            icon: const Icon(Icons.search),
            onPressed: () {
              // 聚焦到搜索框
              FocusScope.of(context).requestFocus(FocusNode());
            },
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
      body: Column(
        children: [
          // 搜索栏
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

          // 筛选器
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

          // 条目列表
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: entries.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _EntryCard(
                        entry: entry,
                        onTap: () => _navigateToEntryDetail(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddEntry,
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? '未找到匹配的条目' : '暂无条目',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? '尝试其他搜索词'
                : '点击下方按钮添加您的第一个条目',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;

  const _EntryCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(entry.type),
          child: Icon(
            _getTypeIcon(entry.type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: entry.tags.isNotEmpty
            ? Text(
                entry.tags.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                _getTypeName(entry.type),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: entry.isFavorite
            ? const Icon(Icons.star, color: Colors.amber)
            : null,
        onTap: onTap,
      ),
    );
  }

  IconData _getTypeIcon(EntryType type) {
    return switch (type) {
      EntryType.login => Icons.login,
      EntryType.bankCard => Icons.credit_card,
      EntryType.secureNote => Icons.note,
      EntryType.identity => Icons.person,
    };
  }

  Color _getTypeColor(EntryType type) {
    return switch (type) {
      EntryType.login => Colors.blue,
      EntryType.bankCard => Colors.green,
      EntryType.secureNote => Colors.orange,
      EntryType.identity => Colors.purple,
    };
  }

  String _getTypeName(EntryType type) {
    return switch (type) {
      EntryType.login => '登录凭证',
      EntryType.bankCard => '银行卡',
      EntryType.secureNote => '安全笔记',
      EntryType.identity => '身份信息',
    };
  }
}
