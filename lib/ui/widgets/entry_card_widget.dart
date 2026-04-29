import 'package:flutter/material.dart';
import '../../core/models/vault_entry.dart';
import 'entry_type_helper.dart';

class EntryCardWidget extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;

  const EntryCardWidget({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: EntryTypeHelper.getColor(entry.type),
          child: Icon(
            EntryTypeHelper.getIcon(entry.type),
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
                EntryTypeHelper.getName(entry.type),
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
}
