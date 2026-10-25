import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/vault_entry.dart';
import 'vault_providers.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../features/tools/password_generator.dart';
import 'widgets/entry_type_helper.dart';
import 'widgets/type_picker.dart';
import '../../../ui/theme/tokens.dart';
import 'widgets/entry_forms/entry_form_controllers.dart';
import 'widgets/entry_forms/login_form_section.dart';
import 'widgets/entry_forms/bank_card_form_section.dart';
import 'widgets/entry_forms/secure_note_form_section.dart';
import 'widgets/entry_forms/identity_form_section.dart';

/// 添加/编辑条目页（骨架）。
///
/// 页面只负责：类型选择、通用字段（标题/标签）、分区组装与保存流程；
/// 各条目类型的专属字段渲染在 widgets/entry_forms/ 下的对应分区组件中，
/// 表单控制器统一由 [EntryFormControllers] 管理生命周期。
class AddEntryPage extends ConsumerStatefulWidget {
  final String? entryId;
  final EntryType? initialEntryType;

  const AddEntryPage({
    super.key,
    this.entryId,
    this.initialEntryType,
  });

  @override
  ConsumerState<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends ConsumerState<AddEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late EntryType _selectedType;
  bool _isEditing = false;
  VaultEntry? _originalEntry;

  late final EntryFormControllers _c = EntryFormControllers();
  final BankCardFormState _bankCardState = BankCardFormState();
  final IdentityFormState _identityState = IdentityFormState();
  bool _isMarkdown = false;

  int _passwordStrength = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialEntryType ?? EntryType.login;

    _c.password.addListener(_updatePasswordStrength);

    if (widget.entryId != null) {
      _isEditing = true;
      _loadEntry();
    }
  }

  @override
  void dispose() {
    _c.password.removeListener(_updatePasswordStrength);
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final entry = ref.read(vaultEntryByIdProvider(widget.entryId!));

    if (entry != null && mounted) {
      setState(() {
        _originalEntry = entry;
        _selectedType = entry.type;
        _c.loadFrom(entry);

        switch (entry.type) {
          case EntryType.bankCard:
            if (entry is BankCardEntry) {
              _bankCardState.expiryMonth = entry.expiryMonth;
              _bankCardState.expiryYear = entry.expiryYear;
              _bankCardState.cardType = entry.cardType ?? CardType.other;
            }
            break;
          case EntryType.secureNote:
            if (entry is SecureNoteEntry) {
              _isMarkdown = entry.isMarkdown;
            }
            break;
          case EntryType.identity:
            if (entry is IdentityEntry) {
              _identityState.birthDate = entry.birthDate;
            }
            break;
          case EntryType.login:
          case EntryType.custom:
            break;
        }
      });
    }
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength =
          PasswordGenerator.calculateStrength(_c.password.text);
    });
  }

  /// 构建条目并写入保险库（由 _saveEntry 包裹，负责 loading 状态）。
  Future<void> _persistEntry() async {
    final vaultNotifier = ref.read(vaultNotifierProvider.notifier);

    final tags = _c.tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final now = DateTime.now();
    final id = _isEditing && _originalEntry != null
        ? _originalEntry!.id
        : DateTime.now().millisecondsSinceEpoch.toString();
    final createdAt = _isEditing && _originalEntry != null
        ? _originalEntry!.createdAt
        : now;

    VaultEntry entry;

    switch (_selectedType) {
      case EntryType.login:
        entry = LoginEntry(
          id: id,
          title: _c.title.text,
          createdAt: createdAt,
          updatedAt: now,
          tags: tags,
          username: _c.username.text.isNotEmpty ? _c.username.text : null,
          email: _c.email.text.isNotEmpty ? _c.email.text : null,
          password: _c.password.text.isNotEmpty ? _c.password.text : null,
          url: _c.url.text.isNotEmpty ? _c.url.text : null,
          notes: _c.notes.text.isNotEmpty ? _c.notes.text : null,
          totpSecret:
              _c.totpSecret.text.isNotEmpty ? _c.totpSecret.text : null,
        );
        break;
      case EntryType.bankCard:
        entry = BankCardEntry(
          id: id,
          title: _c.title.text,
          createdAt: createdAt,
          updatedAt: now,
          tags: tags,
          cardNumber: _c.cardNumber.text.isNotEmpty ? _c.cardNumber.text : null,
          cardHolderName:
              _c.cardHolder.text.isNotEmpty ? _c.cardHolder.text : null,
          cvv: _c.cvv.text.isNotEmpty ? _c.cvv.text : null,
          bankName: _c.bankName.text.isNotEmpty ? _c.bankName.text : null,
          expiryMonth: _bankCardState.expiryMonth,
          expiryYear: _bankCardState.expiryYear,
          cardType: _bankCardState.cardType,
        );
        break;
      case EntryType.secureNote:
        entry = SecureNoteEntry(
          id: id,
          title: _c.title.text,
          createdAt: createdAt,
          updatedAt: now,
          tags: tags,
          content:
              _c.noteContent.text.isNotEmpty ? _c.noteContent.text : null,
          isMarkdown: _isMarkdown,
        );
        break;
      case EntryType.identity:
        entry = IdentityEntry(
          id: id,
          title: _c.title.text,
          createdAt: createdAt,
          updatedAt: now,
          tags: tags,
          firstName: _c.firstName.text.isNotEmpty ? _c.firstName.text : null,
          lastName: _c.lastName.text.isNotEmpty ? _c.lastName.text : null,
          middleName:
              _c.middleName.text.isNotEmpty ? _c.middleName.text : null,
          idNumber: _c.idNumber.text.isNotEmpty ? _c.idNumber.text : null,
          phone: _c.phone.text.isNotEmpty ? _c.phone.text : null,
          email: _c.email.text.isNotEmpty ? _c.email.text : null,
          address: _c.address.text.isNotEmpty ? _c.address.text : null,
          birthDate: _identityState.birthDate,
        );
        break;
      case EntryType.custom:
        entry = VaultEntry(
          id: id,
          title: _c.title.text,
          createdAt: createdAt,
          updatedAt: now,
          type: EntryType.custom,
          tags: tags,
        );
        break;
    }

    bool success;
    if (_isEditing) {
      success = await vaultNotifier.updateEntry(entry);
    } else {
      success = await vaultNotifier.addEntry(entry);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '条目更新成功' : '条目添加成功')),
      );
      context.pop();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('保存失败: ${ref.read(vaultNotifierProvider).error ?? '未知错误'}')),
      );
    }
  }

  Future<void> _saveEntry() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _persistEntry();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑条目' : '添加条目'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveEntry,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          children: [
            if (!_isEditing) ...[
              EntryTypePicker(
                value: _selectedType,
                onChanged: (value) {
                  setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: AppTokens.spaceL),
            ],

            SectionCard(
              title: '基本信息',
              icon: Icons.info_outline,
              children: [
                TextFormField(
                  controller: _c.title,
                  decoration: const InputDecoration(
                    labelText: '标题 *',
                    hintText: '例如：Google 账号',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入标题';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTokens.spaceL),
                TextFormField(
                  controller: _c.tags,
                  decoration: const InputDecoration(
                    labelText: '标签',
                    hintText: '用逗号分隔多个标签',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
              ],
            ),

            SectionCard(
              title: _typeSectionTitle,
              icon: _typeSectionIcon,
              children: _buildTypeSpecificFields(),
            ),

            LoadingButton.filled(
              onPressed: _saveEntry,
              icon: Icons.save,
              label: _isEditing ? '更新条目' : '添加条目',
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  /// 当前类型的分区标题
  String get _typeSectionTitle => switch (_selectedType) {
    EntryType.login => '登录凭证',
    EntryType.bankCard => '银行卡信息',
    EntryType.secureNote => '笔记内容',
    EntryType.identity => '身份信息',
    EntryType.custom => '自定义字段',
  };

  /// 当前类型的分区图标
  IconData get _typeSectionIcon => EntryTypeHelper.getIcon(_selectedType);

  List<Widget> _buildTypeSpecificFields() {
    switch (_selectedType) {
      case EntryType.login:
        return [
          LoginFormSection(
            controllers: _c,
            passwordStrength: _passwordStrength,
            onPasswordChanged: () {},
          ),
        ];
      case EntryType.bankCard:
        return [
          BankCardFormSection(controllers: _c, state: _bankCardState),
        ];
      case EntryType.secureNote:
        return [
          SecureNoteFormSection(
            controllers: _c,
            isMarkdown: _isMarkdown,
            onMarkdownChanged: (value) => setState(() => _isMarkdown = value),
          ),
        ];
      case EntryType.identity:
        return [
          IdentityFormSection(controllers: _c, state: _identityState),
        ];
      case EntryType.custom:
        return const [];
    }
  }
}
