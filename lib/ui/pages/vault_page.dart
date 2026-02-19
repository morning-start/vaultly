import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/vault_entry.dart';
import '../../core/services/vault_service.dart';
import 'unlock_page.dart';
import 'add_entry_page.dart';
import 'entry_detail_page.dart';

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

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
    await vaultService.loadVault();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultEntry> _getFilteredEntries() {
    final vaultService = ref.read(vaultServiceProvider);
    var entries = vaultService.getAllEntries();

    if (_selectedFilter != null) {
      entries = entries.where((e) => e.type == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      entries = vaultService.searchEntries(_searchQuery);
      if (_selectedFilter != null) {
        entries = entries.where((e) => e.type == _selectedFilter).toList();
      }
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _getFilteredEntries();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaultly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UnlockPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
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
            child: entries.isEmpty
                ? Center(
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
                          '暂无条目',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击下方按钮添加您的第一个条目',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _EntryCard(
                        entry: entry,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EntryDetailPage(entry: entry),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEntryPage()),
          );
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('添加'),
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
        title: Text(entry.title),
        subtitle: entry.tags.isNotEmpty
            ? Text(
                entry.tags.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(_getTypeName(entry.type)),
        trailing: entry.isFavorite
            ? const Icon(Icons.star, color: Colors.amber)
            : null,
        onTap: onTap,
      ),
    );
  }

  IconData _getTypeIcon(EntryType type) {
    switch (type) {
      case EntryType.login:
        return Icons.login;
      case EntryType.bankCard:
        return Icons.credit_card;
      case EntryType.secureNote:
        return Icons.note;
      case EntryType.identity:
        return Icons.person;
      case EntryType.custom:
        return Icons.folder;
    }
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.login:
        return Colors.blue;
      case EntryType.bankCard:
        return Colors.green;
      case EntryType.secureNote:
        return Colors.orange;
      case EntryType.identity:
        return Colors.purple;
      case EntryType.custom:
        return Colors.grey;
    }
  }

  String _getTypeName(EntryType type) {
    switch (type) {
      case EntryType.login:
        return '登录凭证';
      case EntryType.bankCard:
        return '银行卡';
      case EntryType.secureNote:
        return '安全笔记';
      case EntryType.identity:
        return '身份信息';
      case EntryType.custom:
        return '自定义';
    }
  }
}
