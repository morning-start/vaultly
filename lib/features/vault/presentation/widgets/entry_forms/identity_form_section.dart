import 'package:flutter/material.dart';
import '../../../../../shared/widgets/secure_text_field.dart';
import '../../../../../ui/theme/tokens.dart';
import 'entry_form_controllers.dart';

/// 身份信息表单分区（含出生日期选择）。
class IdentityFormSection extends StatefulWidget {
  final EntryFormControllers controllers;
  final IdentityFormState state;

  const IdentityFormSection({
    super.key,
    required this.controllers,
    required this.state,
  });

  @override
  State<IdentityFormSection> createState() => _IdentityFormSectionState();
}

class _IdentityFormSectionState extends State<IdentityFormSection> {
  EntryFormControllers get _c => widget.controllers;
  IdentityFormState get _s => widget.state;

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _s.birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _s.birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthDate = _s.birthDate;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _c.firstName,
                decoration: const InputDecoration(
                  labelText: '名',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: AppTokens.spaceL),
            Expanded(
              child: TextFormField(
                controller: _c.lastName,
                decoration: const InputDecoration(
                  labelText: '姓',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: _c.middleName,
          decoration: const InputDecoration(
            labelText: '中间名',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppTokens.spaceL),
        ListTile(
          leading: const Icon(Icons.cake),
          title: const Text('出生日期'),
          subtitle: Text(
            birthDate != null
                ? '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
                : '未设置',
          ),
          trailing: TextButton(
            onPressed: _selectBirthDate,
            child: const Text('选择'),
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        SecureTextField(
          controller: _c.idNumber,
          labelText: '证件号码',
          prefixIcon: Icons.badge,
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: _c.phone,
          decoration: const InputDecoration(
            labelText: '电话号码',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: _c.email,
          decoration: const InputDecoration(
            labelText: '邮箱',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: _c.address,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '地址',
            prefixIcon: Icon(Icons.location_on),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
