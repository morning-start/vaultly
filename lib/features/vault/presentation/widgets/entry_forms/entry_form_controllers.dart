import 'package:flutter/material.dart';
import '../../../domain/vault_entry.dart';

/// 银行卡表单局部状态（有效期与卡类型）。
class BankCardFormState {
  int? expiryMonth;
  int? expiryYear;
  CardType cardType;

  BankCardFormState({
    this.expiryMonth,
    this.expiryYear,
    this.cardType = CardType.other,
  });

  /// 从已有条目恢复。
  factory BankCardFormState.of(BankCardEntry? entry) => BankCardFormState(
        expiryMonth: entry?.expiryMonth,
        expiryYear: entry?.expiryYear,
        cardType: entry?.cardType ?? CardType.other,
      );
}

/// 身份表单局部状态（出生日期）。
class IdentityFormState {
  DateTime? birthDate;

  IdentityFormState({this.birthDate});

  factory IdentityFormState.of(IdentityEntry? entry) =>
      IdentityFormState(birthDate: entry?.birthDate);
}

/// 添加/编辑条目页的表单控制器集合。
///
/// 集中持有全部 TextEditingController，由 AddEntryPage 统一创建与销毁；
/// 各类型 FormSection 只负责渲染与校验，不管理生命周期。
class EntryFormControllers {
  // 通用
  final title = TextEditingController();
  final tags = TextEditingController();

  // 登录凭证
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final url = TextEditingController();
  final notes = TextEditingController();
  final totpSecret = TextEditingController();

  // 银行卡
  final cardNumber = TextEditingController();
  final cardHolder = TextEditingController();
  final cvv = TextEditingController();
  final bankName = TextEditingController();

  // 安全笔记
  final noteContent = TextEditingController();

  // 身份
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final middleName = TextEditingController();
  final idNumber = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  /// 从已有条目回填全部字段。
  void loadFrom(VaultEntry entry) {
    title.text = entry.title;
    tags.text = entry.tags.join(', ');

    if (entry is LoginEntry) {
      username.text = entry.username ?? '';
      email.text = entry.email ?? '';
      password.text = entry.password ?? '';
      url.text = entry.url ?? '';
      notes.text = entry.notes ?? '';
      totpSecret.text = entry.totpSecret ?? '';
    } else if (entry is BankCardEntry) {
      cardNumber.text = entry.cardNumber ?? '';
      cardHolder.text = entry.cardHolderName ?? '';
      cvv.text = entry.cvv ?? '';
      bankName.text = entry.bankName ?? '';
    } else if (entry is SecureNoteEntry) {
      noteContent.text = entry.content ?? '';
    } else if (entry is IdentityEntry) {
      firstName.text = entry.firstName ?? '';
      lastName.text = entry.lastName ?? '';
      middleName.text = entry.middleName ?? '';
      idNumber.text = entry.idNumber ?? '';
      phone.text = entry.phone ?? '';
      email.text = entry.email ?? '';
      address.text = entry.address ?? '';
    }
  }

  void dispose() {
    for (final c in [
      title, tags, username, email, password, url, notes, totpSecret,
      cardNumber, cardHolder, cvv, bankName, noteContent,
      firstName, lastName, middleName, idNumber, phone, address,
    ]) {
      c.dispose();
    }
  }
}
