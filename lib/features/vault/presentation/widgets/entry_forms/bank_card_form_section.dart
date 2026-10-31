import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../shared/widgets/secure_text_field.dart';
import '../../../../../ui/theme/tokens.dart';
import '../../../../tools/ocr_service.dart';
import 'package:vaultly_core/vaultly_core.dart';
import '../../widgets/entry_type_helper.dart';
import 'entry_form_controllers.dart';

/// 银行卡表单分区（含 OCR 扫卡入口与有效期选择）。
class BankCardFormSection extends StatefulWidget {
  final EntryFormControllers controllers;
  final BankCardFormState state;

  const BankCardFormSection({
    super.key,
    required this.controllers,
    required this.state,
  });

  @override
  State<BankCardFormSection> createState() => _BankCardFormSectionState();
}

class _BankCardFormSectionState extends State<BankCardFormSection> {
  EntryFormControllers get _c => widget.controllers;
  BankCardFormState get _s => widget.state;

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => _ExpiryDatePicker(
        initialMonth: _s.expiryMonth ?? now.month,
        initialYear: _s.expiryYear ?? now.year + 3,
      ),
    );

    if (result != null) {
      setState(() {
        _s.expiryMonth = result['month'];
        _s.expiryYear = result['year'];
      });
    }
  }

  Future<void> _scanBankCard() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照识别'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从图库选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final ocrService = OcrService();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在识别银行卡信息...'),
                ],
              ),
            ),
          ),
        ),
      );

      final OcrResult result = source == ImageSource.camera
          ? await ocrService.scanFromCamera()
          : await ocrService.scanFromGallery();

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载提示

      if (result.hasAnyData) {
        setState(() {
          if (result.cardNumber != null) {
            // 格式化卡号：每4位一组显示
            final digits = result.cardNumber!.replaceAll(RegExp(r'\s'), '');
            final buffer = StringBuffer();
            for (int i = 0; i < digits.length; i++) {
              if (i > 0 && i % 4 == 0) buffer.write(' ');
              buffer.write(digits[i]);
            }
            _c.cardNumber.text = buffer.toString();
          }
          if (result.cardHolderName != null) {
            _c.cardHolder.text = result.cardHolderName!;
          }
          if (result.expiryMonth != null && result.expiryYear != null) {
            _s.expiryMonth = result.expiryMonth;
            _s.expiryYear = result.expiryYear;
          }
        });

        final detected = <String>[];
        if (result.cardNumber != null) detected.add('卡号');
        if (result.cardHolderName != null) detected.add('持卡人');
        if (result.expiryMonth != null) detected.add('有效期');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                detected.isNotEmpty
                    ? '已识别: ${detected.join('、')}'
                    : '未识别到银行卡信息，请尝试更清晰的图片',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未识别到银行卡信息，请尝试更清晰的图片')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('识别失败: $e')));
    } finally {
      ocrService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SecureTextField(
          controller: _c.cardNumber,
          labelText: '卡号 *',
          prefixIcon: Icons.credit_card,
          suffixIcon: IconButton(
            icon: const Icon(Icons.document_scanner),
            onPressed: _scanBankCard,
            tooltip: '扫描银行卡',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入卡号';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTokens.spaceL),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: '卡类型',
            prefixIcon: Icon(Icons.payment),
          ),
          child: DropdownButton<CardType>(
            value: _s.cardType,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: CardType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(EntryTypeHelper.getCardTypeName(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _s.cardType = value);
              }
            },
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: _c.cardHolder,
          decoration: const InputDecoration(
            labelText: '持卡人姓名',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppTokens.spaceL),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('有效期'),
          subtitle: Text(
            _s.expiryMonth != null && _s.expiryYear != null
                ? '${_s.expiryMonth.toString().padLeft(2, '0')}/'
                      '${_s.expiryYear}'
                : '未设置',
          ),
          trailing: TextButton(
            onPressed: _selectExpiryDate,
            child: const Text('选择'),
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        SecureTextField(
          controller: _c.cvv,
          labelText: 'CVV',
          prefixIcon: Icons.security,
        ),
        const SizedBox(height: AppTokens.spaceL),
        TextFormField(
          controller: _c.bankName,
          decoration: const InputDecoration(
            labelText: '银行名称',
            prefixIcon: Icon(Icons.account_balance),
          ),
        ),
      ],
    );
  }
}

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
          const SizedBox(width: AppTokens.spaceL),
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '年'),
              child: DropdownButton<int>(
                value: _year,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: years.map((y) {
                  return DropdownMenuItem(value: y, child: Text(y.toString()));
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
          onPressed: () =>
              Navigator.pop(context, {'month': _month, 'year': _year}),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
