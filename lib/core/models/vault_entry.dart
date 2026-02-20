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

class CustomField {
  final String name;
  final String value;
  final FieldType type;
  final bool isSecret;

  CustomField({
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
}

class VaultEntry {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final EntryType type;
  List<CustomField> customFields;
  List<String> tags;
  bool isFavorite;
  String? folderId;

  VaultEntry({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.customFields = const [],
    this.tags = const [],
    this.isFavorite = false,
    this.folderId,
  });

  String get uuid => id;

  void touch() {
    updatedAt = DateTime.now();
  }

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
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
        .toList() ?? [],
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    isFavorite: json['isFavorite'] as bool? ?? false,
    folderId: json['folderId'] as String?,
  );

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
}

class LoginEntry extends VaultEntry {
  String? username;
  String? email;
  String? password;
  String? url;
  String? totpSecret;
  String? notes;

  LoginEntry({
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
    return LoginEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      type: EntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EntryType.login,
      ),
      customFields: (json['customFields'] as List<dynamic>?)
          ?.map((e) => CustomField.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      url: json['url'] as String?,
      totpSecret: json['totpSecret'] as String?,
      notes: json['notes'] as String?,
    );
  }

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
}

class BankCardEntry extends VaultEntry {
  String? cardNumber;
  String? cardHolderName;
  int? expiryMonth;
  int? expiryYear;
  String? cvv;
  String? bankName;
  CardType? cardType;

  BankCardEntry({
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
    return BankCardEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      type: EntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EntryType.bankCard,
      ),
      customFields: (json['customFields'] as List<dynamic>?)
          ?.map((e) => CustomField.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      folderId: json['folderId'] as String?,
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
}

class SecureNoteEntry extends VaultEntry {
  String? content;
  bool isMarkdown;

  SecureNoteEntry({
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
    return SecureNoteEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      type: EntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EntryType.secureNote,
      ),
      customFields: (json['customFields'] as List<dynamic>?)
          ?.map((e) => CustomField.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      content: json['content'] as String?,
      isMarkdown: json['isMarkdown'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'content': content,
    'isMarkdown': isMarkdown,
  };
}

class IdentityEntry extends VaultEntry {
  String? firstName;
  String? lastName;
  String? middleName;
  DateTime? birthDate;
  String? idNumber;
  String? address;
  String? phone;
  String? email;

  IdentityEntry({
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
    return IdentityEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      type: EntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EntryType.identity,
      ),
      customFields: (json['customFields'] as List<dynamic>?)
          ?.map((e) => CustomField.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      folderId: json['folderId'] as String?,
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
}
