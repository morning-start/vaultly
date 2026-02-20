import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/vault_entry.dart';
import '../../core/providers/vault_service_provider.dart';
import '../../core/utils/password_generator.dart';
import '../widgets/password_generator_dialog.dart';

/// 添加/编辑条目页面
///
/// 支持多种条目类型：登录凭证、银行卡、安全笔记、身份信息
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

  // 基础字段
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();

  // 登录凭证字段
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final _totpSecretController = TextEditingController();

  // 银行卡字段
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _cvvController = TextEditingController();
  final _bankNameController = TextEditingController();
  int? _expiryMonth;
  int? _expiryYear;
  CardType _cardType = CardType.other;

  // 安全笔记字段
  final _noteContentController = TextEditingController();
  bool _isMarkdown = false;

  // 身份信息字段
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _birthDate;

  // UI 状态
  bool _obscurePassword = true;
  bool _obscureCvv = true;
  bool _obscureIdNumber = true;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialEntryType ?? EntryType.login;
    _passwordController.addListener(_updatePasswordStrength);

    // 如果是编辑模式，加载现有条目
    if (widget.entryId != null) {
      _isEditing = true;
      _loadEntry();
    }
  }

  Future<void> _loadEntry() async {
    final vaultService = ref.read(vaultServiceProvider);
    final entry = vaultService.getEntry(widget.entryId!);

    if (entry != null && mounted) {
      setState(() {
        _originalEntry = entry;
        _selectedType = entry.type;
        _titleController.text = entry.title;
        _tagsController.text = entry.tags.join(', ');

        // 加载类型特定字段
        switch (entry.type) {
          case EntryType.login:
            _usernameController.text = entry.usernameEncrypted ?? '';
            _emailController.text = entry.emailEncrypted ?? '';
            _passwordController.text = entry.passwordEncrypted ?? '';
            _urlController.text = entry.url ?? '';
            _notesController.text = entry.notesEncrypted ?? '';
            _totpSecretController.text = entry.totpSecretEncrypted ?? '';
            break;
          case EntryType.bankCard:
            _cardNumberController.text = entry.cardNumberEncrypted ?? '';
            _cardHolderController.text = entry.cardHolderName ?? '';
            _cvvController.text = entry.cvvEncrypted ?? '';
            _bankNameController.text = entry.bankName ?? '';
            _expiryMonth = entry.expiryMonth;
            _expiryYear = entry.expiryYear;
            _cardType = entry.cardType ?? CardType.other;
            break;
          case EntryType.secureNote:
            _noteContentController.text = entry.noteContentEncrypted ?? '';
            _isMarkdown = entry.isMarkdown;
            break;
          case EntryType.identity:
            _firstNameController.text = entry.firstName ?? '';
            _lastNameController.text = entry.lastName ?? '';
            _middleNameController.text = entry.middleName ?? '';
            _idNumberController.text = entry.idNumberEncrypted ?? '';
            _phoneController.text = entry.phoneEncrypted ?? '';
            _emailController.text = entry.emailEncrypted ?? '';
            _addressController.text = entry.addressEncrypted ?? '';
            _birthDate = entry.birthDate;
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _totpSecretController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _cvvController.dispose();
    _bankNameController.dispose();
    _noteContentController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength = PasswordGenerator.calculateStrength(_passwordController.text);
    });
  }

  Future<void> _showPasswordGenerator() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => PasswordGeneratorDialog(
        initialPassword: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      ),
    );

    if (password != null) {
      _passwordController.text = password;
      setState(() => _obscurePassword = false);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final vaultService = ref.read(vaultServiceProvider);

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    VaultEntry entry;

    if (_isEditing && _originalEntry != null) {
      // 更新现有条目
      entry = _originalEntry!;
      entry.title = _titleController.text;
      entry.type = _selectedType;
      entry.tags = tags;
      entry.updatedAt = DateTime.now();
    } else {
      // 创建新条目
      entry = VaultEntry(
        title: _titleController.text,
        type: _selectedType,
        tags: tags,
      );
    }

    // 根据类型设置字段
    switch (_selectedType) {
      case EntryType.login:
        entry.usernameEncrypted = _usernameController.text.isNotEmpty ? _usernameController.text : null;
        entry.emailEncrypted = _emailController.text.isNotEmpty ? _emailController.text : null;
        entry.passwordEncrypted = _passwordController.text.isNotEmpty ? _passwordController.text : null;
        entry.url = _urlController.text.isNotEmpty ? _urlController.text : null;
        entry.notesEncrypted = _notesController.text.isNotEmpty ? _notesController.text : null;
        entry.totpSecretEncrypted = _totpSecretController.text.isNotEmpty ? _totpSecretController.text : null;
        break;
      case EntryType.bankCard:
        entry.cardNumberEncrypted = _cardNumberController.text.isNotEmpty ? _cardNumberController.text : null;
        entry.cardHolderName = _cardHolderController.text.isNotEmpty ? _cardHolderController.text : null;
        entry.cvvEncrypted = _cvvController.text.isNotEmpty ? _cvvController.text : null;
        entry.bankName = _bankNameController.text.isNotEmpty ? _bankNameController.text : null;
        entry.expiryMonth = _expiryMonth;
        entry.expiryYear = _expiryYear;
        entry.cardType = _cardType;
        break;
      case EntryType.secureNote:
        entry.noteContentEncrypted = _noteContentController.text.isNotEmpty ? _noteContentController.text : null;
        entry.isMarkdown = _isMarkdown;
        break;
      case EntryType.identity:
        entry.firstName = _firstNameController.text.isNotEmpty ? _firstNameController.text : null;
        entry.lastName = _lastNameController.text.isNotEmpty ? _lastNameController.text : null;
        entry.middleName = _middleNameController.text.isNotEmpty ? _middleNameController.text : null;
        entry.idNumberEncrypted = _idNumberController.text.isNotEmpty ? _idNumberController.text : null;
        entry.phoneEncrypted = _phoneController.text.isNotEmpty ? _phoneController.text : null;
        entry.emailEncrypted = _emailController.text.isNotEmpty ? _emailController.text : null;
        entry.addressEncrypted = _addressController.text.isNotEmpty ? _addressController.text : null;
        entry.birthDate = _birthDate;
        break;
    }

    if (_isEditing) {
      await vaultService.updateEntry(entry);
    } else {
      await vaultService.addEntry(entry);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '条目更新成功' : '条目添加成功')),
      );
      context.pop();
    }
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => _ExpiryDatePicker(
        initialMonth: _expiryMonth ?? now.month,
        initialYear: _expiryYear ?? now.year + 3,
      ),
    );

    if (result != null) {
      setState(() {
        _expiryMonth = result['month'];
        _expiryYear = result['year'];
      });
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑条目' : '添加条目'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 条目类型选择（仅在添加时显示）
            if (!_isEditing)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '条目类型',
                  prefixIcon: Icon(Icons.category),
                ),
                child: DropdownButton<EntryType>(
                  value: _selectedType,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: EntryType.login, child: Text('登录凭证')),
                    DropdownMenuItem(value: EntryType.bankCard, child: Text('银行卡')),
                    DropdownMenuItem(value: EntryType.secureNote, child: Text('安全笔记')),
                    DropdownMenuItem(value: EntryType.identity, child: Text('身份信息')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
              ),
            if (!_isEditing) const SizedBox(height: 16),

            // 标题
            TextFormField(
              controller: _titleController,
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
            const SizedBox(height: 16),

            // 类型特定字段
            ..._buildTypeSpecificFields(),

            const SizedBox(height: 16),

            // 标签
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '用逗号分隔多个标签',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton.icon(
              onPressed: _saveEntry,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? '更新条目' : '添加条目'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeSpecificFields() {
    switch (_selectedType) {
      case EntryType.login:
        return _buildLoginFields();
      case EntryType.bankCard:
        return _buildBankCardFields();
      case EntryType.secureNote:
        return _buildSecureNoteFields();
      case EntryType.identity:
        return _buildIdentityFields();
    }
  }

  List<Widget> _buildLoginFields() {
    return [
      TextFormField(
        controller: _usernameController,
        decoration: const InputDecoration(
          labelText: '用户名',
          hintText: '用户名或账号',
          prefixIcon: Icon(Icons.person),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: '邮箱',
          prefixIcon: Icon(Icons.email),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: '密码',
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: _showPasswordGenerator,
                tooltip: '生成密码',
              ),
            ],
          ),
        ),
      ),
      if (_passwordController.text.isNotEmpty) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _passwordStrength / 100,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(_getStrengthColor()),
        ),
        const SizedBox(height: 4),
        Text(
          '密码强度: ${_getStrengthText()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _getStrengthColor(),
          ),
        ),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: _urlController,
        decoration: const InputDecoration(
          labelText: '网站 URL',
          hintText: 'https://example.com',
          prefixIcon: Icon(Icons.link),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _totpSecretController,
        decoration: const InputDecoration(
          labelText: 'TOTP 密钥',
          hintText: '用于双因素认证',
          prefixIcon: Icon(Icons.timer),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _notesController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: '备注',
          prefixIcon: Icon(Icons.note),
        ),
      ),
    ];
  }

  List<Widget> _buildBankCardFields() {
    return [
      TextFormField(
        controller: _cardNumberController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: '卡号 *',
          prefixIcon: Icon(Icons.credit_card),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '请输入卡号';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      InputDecorator(
        decoration: const InputDecoration(
          labelText: '卡类型',
          prefixIcon: Icon(Icons.payment),
        ),
        child: DropdownButton<CardType>(
          value: _cardType,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: CardType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getCardTypeName(type)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _cardType = value);
            }
          },
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cardHolderController,
        decoration: const InputDecoration(
          labelText: '持卡人姓名',
          prefixIcon: Icon(Icons.person),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('有效期'),
        subtitle: Text(_expiryMonth != null && _expiryYear != null
            ? '${_expiryMonth.toString().padLeft(2, '0')}/$_expiryYear'
            : '未设置'),
        trailing: TextButton(
          onPressed: _selectExpiryDate,
          child: const Text('选择'),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cvvController,
        obscureText: _obscureCvv,
        decoration: InputDecoration(
          labelText: 'CVV',
          prefixIcon: const Icon(Icons.security),
          suffixIcon: IconButton(
            icon: Icon(_obscureCvv ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
          ),
        ),
        keyboardType: TextInputType.number,
        maxLength: 4,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _bankNameController,
        decoration: const InputDecoration(
          labelText: '银行名称',
          prefixIcon: Icon(Icons.account_balance),
        ),
      ),
    ];
  }

  List<Widget> _buildSecureNoteFields() {
    return [
      SwitchListTile(
        title: const Text('Markdown 格式'),
        subtitle: const Text('启用 Markdown 语法支持'),
        value: _isMarkdown,
        onChanged: (value) => setState(() => _isMarkdown = value),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _noteContentController,
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
    ];
  }

  List<Widget> _buildIdentityFields() {
    return [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: '名',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: '姓',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _middleNameController,
        decoration: const InputDecoration(
          labelText: '中间名',
          prefixIcon: Icon(Icons.person_outline),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.cake),
        title: const Text('出生日期'),
        subtitle: Text(_birthDate != null
            ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
            : '未设置'),
        trailing: TextButton(
          onPressed: _selectBirthDate,
          child: const Text('选择'),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _idNumberController,
        obscureText: _obscureIdNumber,
        decoration: InputDecoration(
          labelText: '证件号码',
          prefixIcon: const Icon(Icons.badge),
          suffixIcon: IconButton(
            icon: Icon(_obscureIdNumber ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureIdNumber = !_obscureIdNumber),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _phoneController,
        decoration: const InputDecoration(
          labelText: '电话号码',
          prefixIcon: Icon(Icons.phone),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: '邮箱',
          prefixIcon: Icon(Icons.email),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _addressController,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: '地址',
          prefixIcon: Icon(Icons.location_on),
          alignLabelWithHint: true,
        ),
      ),
    ];
  }

  Color _getStrengthColor() {
    if (_passwordStrength < 40) return Colors.red;
    if (_passwordStrength < 70) return Colors.orange;
    if (_passwordStrength < 90) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getStrengthText() {
    if (_passwordStrength < 40) return '弱';
    if (_passwordStrength < 70) return '一般';
    if (_passwordStrength < 90) return '强';
    return '非常强';
  }

  String _getCardTypeName(CardType type) {
    return switch (type) {
      CardType.visa => 'Visa',
      CardType.mastercard => 'Mastercard',
      CardType.amex => 'American Express',
      CardType.unionPay => 'UnionPay',
      CardType.other => '其他',
    };
  }
}

/// 有效期选择器
class _ExpiryDatePicker extends StatefulWidget {
  final int initialMonth;
  final int initialYear;

  const _ExpiryDatePicker({
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<_ExpiryDatePicker> createState() => _ExpiryDatePickerState();
}

class _ExpiryDatePickerState extends State<_ExpiryDatePicker> {
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(20, (i) => now.year + i);

    return AlertDialog(
      title: const Text('选择有效期'),
      content: Row(
        children: [
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '月'),
              child: DropdownButton<int>(
                value: _month,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(m.toString().padLeft(2, '0')),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _month = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '年'),
              child: DropdownButton<int>(
                value: _year,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: years.map((y) {
                  return DropdownMenuItem(
                    value: y,
                    child: Text(y.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _year = value);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {'month': _month, 'year': _year}),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
