import 'package:flutter/material.dart';
import '../../../../../ui/theme/tokens.dart';
import 'entry_form_controllers.dart';

/// 安全笔记表单分区。
class SecureNoteFormSection extends StatefulWidget {
  final EntryFormControllers controllers;
  final bool isMarkdown;
  final ValueChanged<bool> onMarkdownChanged;

  const SecureNoteFormSection({
    super.key,
    required this.controllers,
    required this.isMarkdown,
    required this.onMarkdownChanged,
  });

  @override
  State<SecureNoteFormSection> createState() => _SecureNoteFormSectionState();
}

class _SecureNoteFormSectionState extends State<SecureNoteFormSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Markdown 格式'),
          subtitle: const Text('启用 Markdown 语法支持'),
          value: widget.isMarkdown,
          onChanged: widget.onMarkdownChanged,
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: widget.controllers.noteContent,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: '笔记内容 *',
            hintText: '在此输入您的安全笔记...',
            prefixIcon: Icon(Icons.note),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入笔记内容';
            }
            return null;
          },
        ),
      ],
    );
  }
}
