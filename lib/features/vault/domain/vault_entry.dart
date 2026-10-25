/// 保险库条目类型。
///
/// 这些类型用于驱动页面表单、列表展示和字段级加密逻辑。
enum EntryType {
  login,
  bankCard,
  secureNote,
  identity,
  custom,
}

enum CardType {
  visa,
  mastercard,
  amex,
  discover,
  jcb,
  unionPay,
  other,
}

enum FieldType {
  text,
  hidden,
  date,
  url,
  email,
  phone,
  number,
}

/// 自定义字段数据结构（不可变）。
///
/// 支持普通文本、隐藏值、日期、网址、邮箱、手机号和数字等字段。
class CustomField {
  final String name;
  final String value;
  final FieldType type;
  final bool isSecret;

  const CustomField({
    required this.name,
    required this.value,
    this.type = FieldType.text,
    this.isSecret = false,
  });

  factory CustomField.fromJson(Map<String, dynamic> json) => CustomField(
    name: json['name'] as String,
    value: json['value'] as String,
    type: FieldType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FieldType.text,
    ),
    isSecret: json['isSecret'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'type': type.name,
    'isSecret': isSecret,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomField &&
          other.name == name &&
          other.value == value &&
          other.type == type &&
          other.isSecret == isSecret;

  @override
  int get hashCode => Object.hash(name, value, type, isSecret);
}

/// fromJson 共享的 base 字段包（消重辅助）。
///
/// 各子类工厂从持久化 JSON 解析出公共字段后，
/// 经由 `_base` 命名构造转发，避免 base 字段解析模板重复 5 遍。
class VaultBaseData {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EntryType type;
  final List<CustomField> customFields;
  final List<String> tags;
  final bool isFavorite;
  final String? folderId;

  const VaultBaseData({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.type = EntryType.custom,
    this.customFields = const [],
    this.tags = const [],
    this.isFavorite = false,
    this.folderId,
  });

  factory VaultBaseData.fromJson(Map<String, dynamic> json) => VaultBaseData(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    type: EntryType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => EntryType.custom,
    ),
    customFields: (json['customFields'] as List<dynamic>?)
            ?.map((e) => CustomField.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    isFavorite: json['isFavorite'] as bool? ?? false,
    folderId: json['folderId'] as String?,
  );
}

/// 保险库基础条目（不可变）。
///
/// 作为各类条目的公共父类，保存通用元数据、标签、收藏标记和自定义字段。
/// 所有字段均为 final：任何变更通过 [copyWith] 生成新实例，
/// 保证被 Provider/UI 共享的内存态引用不会被就地篡改。
class VaultEntry {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EntryType type;
  final List<CustomField> customFields;
  final List<String> tags;
  final bool isFavorite;
  final String? folderId;

  VaultEntry.base(VaultBaseData b)
      : this(
          id: b.id,
          title: b.title,
          createdAt: b.createdAt,
          updatedAt: b.updatedAt,
          type: b.type,
          customFields: b.customFields,
          tags: b.tags,
          isFavorite: b.isFavorite,
          folderId: b.folderId,
        );

  const VaultEntry({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.type = EntryType.custom,
    this.customFields = const [],
    this.tags = const [],
    this.isFavorite = false,
    this.folderId,
  });

  /// 返回刷新更新时间的新实例（原实例不变）。
  VaultEntry withUpdatedTimestamp({DateTime? at}) =>
      copyWith(updatedAt: at ?? DateTime.now());

  VaultEntry copyWith({
    String? title,
    DateTime? updatedAt,
    List<CustomField>? customFields,
    List<String>? tags,
    bool? isFavorite,
    String? folderId,
    bool clearFolderId = false,
  }) =>
      VaultEntry(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        type: type,
        customFields: customFields ?? this.customFields,
        tags: tags ?? this.tags,
        isFavorite: isFavorite ?? this.isFavorite,
        folderId: clearFolderId ? null : (folderId ?? this.folderId),
      );

  factory VaultEntry.fromJson(Map<String, dynamic> json) =>
      VaultEntry.base(VaultBaseData.fromJson(json));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'type': type.name,
    'customFields': customFields.map((e) => e.toJson()).toList(),
    'tags': tags,
    'isFavorite': isFavorite,
    'folderId': folderId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultEntry &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.title == title &&
          other.updatedAt == updatedAt &&
          other.type == type &&
          other.isFavorite == isFavorite &&
          other.folderId == folderId;

  @override
  int get hashCode => Object.hash(id, title, updatedAt, type, isFavorite);
}

class LoginEntry extends VaultEntry {
  final String? username;
  final String? email;
  final String? password;
  final String? url;
  final String? totpSecret;
  final String? notes;

  LoginEntry.base(
    VaultBaseData b, {
    this.username,
    this.email,
    this.password,
    this.url,
    this.totpSecret,
    this.notes,
  }) : super.base(b);

  const LoginEntry({
    required super.id,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    super.type = EntryType.login,
    super.customFields = const [],
    super.tags = const [],
    super.isFavorite = false,
    super.folderId,
    this.username,
    this.email,
    this.password,
    this.url,
    this.totpSecret,
    this.notes,
  });

  factory LoginEntry.fromJson(Map<String, dynamic> json) {
    final b = VaultBaseData.fromJson(json);
    return LoginEntry.base(
      b,
      username: json['username'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      url: json['url'] as String?,
      totpSecret: json['totpSecret'] as String?,
      notes: json['notes'] as String?,
    );
  }

  @override
  LoginEntry copyWith({
    String? title,
    DateTime? updatedAt,
    List<CustomField>? customFields,
    List<String>? tags,
    bool? isFavorite,
    String? folderId,
    bool clearFolderId = false,
    String? username,
    String? email,
    String? password,
    String? url,
    String? totpSecret,
    String? notes,
    bool clearPassword = false,
    bool clearTotpSecret = false,
  }) =>
      LoginEntry(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        type: type,
        customFields: customFields ?? this.customFields,
        tags: tags ?? this.tags,
        isFavorite: isFavorite ?? this.isFavorite,
        folderId: clearFolderId ? null : (folderId ?? this.folderId),
        username: username ?? this.username,
        email: email ?? this.email,
        password: clearPassword ? null : (password ?? this.password),
        url: url ?? this.url,
        totpSecret: clearTotpSecret ? null : (totpSecret ?? this.totpSecret),
        notes: notes ?? this.notes,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'username': username,
    'email': email,
    'password': password,
    'url': url,
    'totpSecret': totpSecret,
    'notes': notes,
  };

  bool _fieldsEqual(LoginEntry other) =>
      other.username == username &&
      other.email == email &&
      other.password == password &&
      other.url == url &&
      other.totpSecret == totpSecret &&
      other.notes == notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginEntry && super == other && _fieldsEqual(other);

  @override
  int get hashCode =>
      Object.hash(super.hashCode, username, email, password, url, totpSecret,
          notes);
}

class BankCardEntry extends VaultEntry {
  final String? cardNumber;
  final String? cardHolderName;
  final int? expiryMonth;
  final int? expiryYear;
  final String? cvv;
  final String? bankName;
  final CardType? cardType;

  BankCardEntry.base(
    VaultBaseData b, {
    this.cardNumber,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
    this.cvv,
    this.bankName,
    this.cardType,
  }) : super.base(b);

  const BankCardEntry({
    required super.id,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    super.type = EntryType.bankCard,
    super.customFields = const [],
    super.tags = const [],
    super.isFavorite = false,
    super.folderId,
    this.cardNumber,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
    this.cvv,
    this.bankName,
    this.cardType,
  });

  factory BankCardEntry.fromJson(Map<String, dynamic> json) {
    final b = VaultBaseData.fromJson(json);
    return BankCardEntry.base(
      b,
      cardNumber: json['cardNumber'] as String?,
      cardHolderName: json['cardHolderName'] as String?,
      expiryMonth: json['expiryMonth'] as int?,
      expiryYear: json['expiryYear'] as int?,
      cvv: json['cvv'] as String?,
      bankName: json['bankName'] as String?,
      cardType: json['cardType'] != null
          ? CardType.values.firstWhere(
              (e) => e.name == json['cardType'],
              orElse: () => CardType.other,
            )
          : null,
    );
  }

  @override
  BankCardEntry copyWith({
    String? title,
    DateTime? updatedAt,
    List<CustomField>? customFields,
    List<String>? tags,
    bool? isFavorite,
    String? folderId,
    bool clearFolderId = false,
    String? cardNumber,
    String? cardHolderName,
    int? expiryMonth,
    int? expiryYear,
    String? cvv,
    String? bankName,
    CardType? cardType,
    bool clearCardNumber = false,
    bool clearCvv = false,
  }) =>
      BankCardEntry(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        type: type,
        customFields: customFields ?? this.customFields,
        tags: tags ?? this.tags,
        isFavorite: isFavorite ?? this.isFavorite,
        folderId: clearFolderId ? null : (folderId ?? this.folderId),
        cardNumber: clearCardNumber ? null : (cardNumber ?? this.cardNumber),
        cardHolderName: cardHolderName ?? this.cardHolderName,
        expiryMonth: expiryMonth ?? this.expiryMonth,
        expiryYear: expiryYear ?? this.expiryYear,
        cvv: clearCvv ? null : (cvv ?? this.cvv),
        bankName: bankName ?? this.bankName,
        cardType: cardType ?? this.cardType,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'cardNumber': cardNumber,
    'cardHolderName': cardHolderName,
    'expiryMonth': expiryMonth,
    'expiryYear': expiryYear,
    'cvv': cvv,
    'bankName': bankName,
    'cardType': cardType?.name,
  };

  bool _fieldsEqual(BankCardEntry other) =>
      other.cardNumber == cardNumber &&
      other.cardHolderName == cardHolderName &&
      other.expiryMonth == expiryMonth &&
      other.expiryYear == expiryYear &&
      other.cvv == cvv &&
      other.bankName == bankName &&
      other.cardType == cardType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankCardEntry && super == other && _fieldsEqual(other);

  @override
  int get hashCode => Object.hash(super.hashCode, cardNumber, cardHolderName,
      expiryMonth, expiryYear, cvv, bankName, cardType);
}

class SecureNoteEntry extends VaultEntry {
  final String? content;
  final bool isMarkdown;

  SecureNoteEntry.base(
    VaultBaseData b, {
    this.content,
    this.isMarkdown = false,
  }) : super.base(b);

  const SecureNoteEntry({
    required super.id,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    super.type = EntryType.secureNote,
    super.customFields = const [],
    super.tags = const [],
    super.isFavorite = false,
    super.folderId,
    this.content,
    this.isMarkdown = false,
  });

  factory SecureNoteEntry.fromJson(Map<String, dynamic> json) {
    final b = VaultBaseData.fromJson(json);
    return SecureNoteEntry.base(
      b,
      content: json['content'] as String?,
      isMarkdown: json['isMarkdown'] as bool? ?? false,
    );
  }

  @override
  SecureNoteEntry copyWith({
    String? title,
    DateTime? updatedAt,
    List<CustomField>? customFields,
    List<String>? tags,
    bool? isFavorite,
    String? folderId,
    bool clearFolderId = false,
    String? content,
    bool? isMarkdown,
    bool clearContent = false,
  }) =>
      SecureNoteEntry(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        type: type,
        customFields: customFields ?? this.customFields,
        tags: tags ?? this.tags,
        isFavorite: isFavorite ?? this.isFavorite,
        folderId: clearFolderId ? null : (folderId ?? this.folderId),
        content: clearContent ? null : (content ?? this.content),
        isMarkdown: isMarkdown ?? this.isMarkdown,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'content': content,
    'isMarkdown': isMarkdown,
  };

  bool _fieldsEqual(SecureNoteEntry other) =>
      other.content == content && other.isMarkdown == isMarkdown;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecureNoteEntry && super == other && _fieldsEqual(other);

  @override
  int get hashCode => Object.hash(super.hashCode, content, isMarkdown);
}

class IdentityEntry extends VaultEntry {
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final DateTime? birthDate;
  final String? idNumber;
  final String? address;
  final String? phone;
  final String? email;

  IdentityEntry.base(
    VaultBaseData b, {
    this.firstName,
    this.lastName,
    this.middleName,
    this.birthDate,
    this.idNumber,
    this.address,
    this.phone,
    this.email,
  }) : super.base(b);

  const IdentityEntry({
    required super.id,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    super.type = EntryType.identity,
    super.customFields = const [],
    super.tags = const [],
    super.isFavorite = false,
    super.folderId,
    this.firstName,
    this.lastName,
    this.middleName,
    this.birthDate,
    this.idNumber,
    this.address,
    this.phone,
    this.email,
  });

  factory IdentityEntry.fromJson(Map<String, dynamic> json) {
    final b = VaultBaseData.fromJson(json);
    return IdentityEntry.base(
      b,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      middleName: json['middleName'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      idNumber: json['idNumber'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  @override
  IdentityEntry copyWith({
    String? title,
    DateTime? updatedAt,
    List<CustomField>? customFields,
    List<String>? tags,
    bool? isFavorite,
    String? folderId,
    bool clearFolderId = false,
    String? firstName,
    String? lastName,
    String? middleName,
    DateTime? birthDate,
    String? idNumber,
    String? address,
    String? phone,
    String? email,
    bool clearIdNumber = false,
  }) =>
      IdentityEntry(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        type: type,
        customFields: customFields ?? this.customFields,
        tags: tags ?? this.tags,
        isFavorite: isFavorite ?? this.isFavorite,
        folderId: clearFolderId ? null : (folderId ?? this.folderId),
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        middleName: middleName ?? this.middleName,
        birthDate: birthDate ?? this.birthDate,
        idNumber: clearIdNumber ? null : (idNumber ?? this.idNumber),
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'firstName': firstName,
    'lastName': lastName,
    'middleName': middleName,
    'birthDate': birthDate?.toIso8601String(),
    'idNumber': idNumber,
    'address': address,
    'phone': phone,
    'email': email,
  };

  bool _fieldsEqual(IdentityEntry other) =>
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.middleName == middleName &&
      other.birthDate == birthDate &&
      other.idNumber == idNumber &&
      other.address == address &&
      other.phone == phone &&
      other.email == email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentityEntry && super == other && _fieldsEqual(other);

  @override
  int get hashCode => Object.hash(super.hashCode, firstName, lastName,
      middleName, birthDate, idNumber, address, phone, email);
}
