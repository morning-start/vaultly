import 'package:uuid/uuid.dart';

/// 条目类型枚举
enum EntryType {
  login, // 登录凭证
  bankCard, // 银行卡
  secureNote, // 安全笔记
  identity, // 身份信息
}

/// 银行卡类型
enum CardType {
  visa,
  mastercard,
  amex,
  unionPay,
  other,
}

/// 自定义字段类型
enum FieldType {
  text, // 纯文本
  hidden, // 隐藏（密码等）
  date, // 日期
  url, // URL
  email, // 邮箱
  phone, // 电话
}

/// 基础保险库条目
///
/// 参考文档: wiki/03-模块设计/保险库模块.md
/// 所有敏感字段都应加密存储
class VaultEntry {
  /// 唯一标识符
  String uuid;

  /// 条目标题
  String title;

  /// 条目类型
  EntryType type;

  /// 创建时间
  DateTime createdAt;

  /// 更新时间
  DateTime updatedAt;

  /// 是否收藏
  bool isFavorite;

  /// 标签列表
  List<String> tags;

  /// 文件夹 ID（可选）
  String? folderId;

  /// 自定义字段（JSON 字符串，加密存储）
  String? customFieldsEncrypted;

  /// 登录凭证特定字段（加密存储）
  String? usernameEncrypted;
  String? emailEncrypted;
  String? passwordEncrypted;
  String? url;
  String? totpSecretEncrypted;
  String? notesEncrypted;

  /// 银行卡特定字段（加密存储）
  String? cardNumberEncrypted;
  String? cardHolderName;
  int? expiryMonth;
  int? expiryYear;
  String? cvvEncrypted;
  String? bankName;
  CardType? cardType;

  /// 安全笔记特定字段（加密存储）
  String? noteContentEncrypted;
  bool isMarkdown;

  /// 身份信息特定字段（加密存储）
  String? firstName;
  String? lastName;
  String? middleName;
  DateTime? birthDate;
  String? idNumberEncrypted;
  String? addressEncrypted;
  String? phoneEncrypted;

  /// 构造函数
  VaultEntry({
    String? uuid,
    this.title = '',
    this.type = EntryType.login,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
    List<String>? tags,
    this.folderId,
    this.customFieldsEncrypted,
    this.usernameEncrypted,
    this.emailEncrypted,
    this.passwordEncrypted,
    this.url,
    this.totpSecretEncrypted,
    this.notesEncrypted,
    this.cardNumberEncrypted,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
    this.cvvEncrypted,
    this.bankName,
    this.cardType,
    this.noteContentEncrypted,
    this.isMarkdown = false,
    this.firstName,
    this.lastName,
    this.middleName,
    this.birthDate,
    this.idNumberEncrypted,
    this.addressEncrypted,
    this.phoneEncrypted,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        tags = tags ?? [];

  /// 更新修改时间
  void touch() {
    updatedAt = DateTime.now();
  }

  /// 转换为 JSON（用于同步）
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'title': title,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
      'tags': tags,
      'folderId': folderId,
      'customFieldsEncrypted': customFieldsEncrypted,
      'usernameEncrypted': usernameEncrypted,
      'emailEncrypted': emailEncrypted,
      'passwordEncrypted': passwordEncrypted,
      'url': url,
      'totpSecretEncrypted': totpSecretEncrypted,
      'notesEncrypted': notesEncrypted,
      'cardNumberEncrypted': cardNumberEncrypted,
      'cardHolderName': cardHolderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'cvvEncrypted': cvvEncrypted,
      'bankName': bankName,
      'cardType': cardType?.name,
      'noteContentEncrypted': noteContentEncrypted,
      'isMarkdown': isMarkdown,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'birthDate': birthDate?.toIso8601String(),
      'idNumberEncrypted': idNumberEncrypted,
      'addressEncrypted': addressEncrypted,
      'phoneEncrypted': phoneEncrypted,
    };
  }

  /// 从 JSON 创建（用于同步）
  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      uuid: json['uuid'],
      title: json['title'] ?? '',
      type: EntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EntryType.login,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      folderId: json['folderId'],
      customFieldsEncrypted: json['customFieldsEncrypted'],
      usernameEncrypted: json['usernameEncrypted'],
      emailEncrypted: json['emailEncrypted'],
      passwordEncrypted: json['passwordEncrypted'],
      url: json['url'],
      totpSecretEncrypted: json['totpSecretEncrypted'],
      notesEncrypted: json['notesEncrypted'],
      cardNumberEncrypted: json['cardNumberEncrypted'],
      cardHolderName: json['cardHolderName'],
      expiryMonth: json['expiryMonth'],
      expiryYear: json['expiryYear'],
      cvvEncrypted: json['cvvEncrypted'],
      bankName: json['bankName'],
      cardType: json['cardType'] != null
          ? CardType.values.firstWhere(
              (e) => e.name == json['cardType'],
              orElse: () => CardType.other,
            )
          : null,
      noteContentEncrypted: json['noteContentEncrypted'],
      isMarkdown: json['isMarkdown'] ?? false,
      firstName: json['firstName'],
      lastName: json['lastName'],
      middleName: json['middleName'],
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'])
          : null,
      idNumberEncrypted: json['idNumberEncrypted'],
      addressEncrypted: json['addressEncrypted'],
      phoneEncrypted: json['phoneEncrypted'],
    );
  }

  /// 复制并修改
  VaultEntry copyWith({
    String? uuid,
    String? title,
    EntryType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    List<String>? tags,
    String? folderId,
    String? customFieldsEncrypted,
    String? usernameEncrypted,
    String? emailEncrypted,
    String? passwordEncrypted,
    String? url,
    String? totpSecretEncrypted,
    String? notesEncrypted,
    String? cardNumberEncrypted,
    String? cardHolderName,
    int? expiryMonth,
    int? expiryYear,
    String? cvvEncrypted,
    String? bankName,
    CardType? cardType,
    String? noteContentEncrypted,
    bool? isMarkdown,
    String? firstName,
    String? lastName,
    String? middleName,
    DateTime? birthDate,
    String? idNumberEncrypted,
    String? addressEncrypted,
    String? phoneEncrypted,
  }) {
    return VaultEntry(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? List<String>.from(this.tags),
      folderId: folderId ?? this.folderId,
      customFieldsEncrypted: customFieldsEncrypted ?? this.customFieldsEncrypted,
      usernameEncrypted: usernameEncrypted ?? this.usernameEncrypted,
      emailEncrypted: emailEncrypted ?? this.emailEncrypted,
      passwordEncrypted: passwordEncrypted ?? this.passwordEncrypted,
      url: url ?? this.url,
      totpSecretEncrypted: totpSecretEncrypted ?? this.totpSecretEncrypted,
      notesEncrypted: notesEncrypted ?? this.notesEncrypted,
      cardNumberEncrypted: cardNumberEncrypted ?? this.cardNumberEncrypted,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      cvvEncrypted: cvvEncrypted ?? this.cvvEncrypted,
      bankName: bankName ?? this.bankName,
      cardType: cardType ?? this.cardType,
      noteContentEncrypted: noteContentEncrypted ?? this.noteContentEncrypted,
      isMarkdown: isMarkdown ?? this.isMarkdown,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      birthDate: birthDate ?? this.birthDate,
      idNumberEncrypted: idNumberEncrypted ?? this.idNumberEncrypted,
      addressEncrypted: addressEncrypted ?? this.addressEncrypted,
      phoneEncrypted: phoneEncrypted ?? this.phoneEncrypted,
    );
  }
}

/// 自定义字段模型
class CustomField {
  /// 字段名称
  String name;

  /// 字段值（应在外部加密）
  String? valueEncrypted;

  /// 字段类型
  FieldType type;

  /// 是否为敏感字段
  bool isSecret;

  CustomField({
    this.name = '',
    this.valueEncrypted,
    this.type = FieldType.text,
    this.isSecret = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'valueEncrypted': valueEncrypted,
    'type': type.name,
    'isSecret': isSecret,
  };

  factory CustomField.fromJson(Map<String, dynamic> json) => CustomField(
    name: json['name'] ?? '',
    valueEncrypted: json['valueEncrypted'],
    type: FieldType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FieldType.text,
    ),
    isSecret: json['isSecret'] ?? false,
  );
}

/// 文件夹模型
class Folder {
  /// 唯一标识符
  String uuid;

  /// 文件夹名称
  String name;

  /// 父文件夹 ID（可选，用于嵌套）
  String? parentId;

  /// 创建时间
  DateTime createdAt;

  /// 更新时间
  DateTime updatedAt;

  Folder({
    String? uuid,
    this.name = '',
    this.parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void touch() {
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'name': name,
    'parentId': parentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    uuid: json['uuid'],
    name: json['name'] ?? '',
    parentId: json['parentId'],
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
  );
}

/// 同步元数据
class SyncMetadata {
  /// 条目 UUID
  String entryUuid;

  /// 是否已同步
  bool isSynced;

  /// 最后同步时间
  DateTime? lastSyncedAt;

  /// 本地修改时间
  DateTime localModifiedAt;

  /// 远程修改时间
  DateTime? remoteModifiedAt;

  /// 冲突解决状态
  ConflictStatus conflictStatus;

  /// 删除标记（软删除）
  bool isDeleted;

  SyncMetadata({
    required this.entryUuid,
    this.isSynced = false,
    this.lastSyncedAt,
    DateTime? localModifiedAt,
    this.remoteModifiedAt,
    this.conflictStatus = ConflictStatus.none,
    this.isDeleted = false,
  }) : localModifiedAt = localModifiedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'entryUuid': entryUuid,
    'isSynced': isSynced,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'localModifiedAt': localModifiedAt.toIso8601String(),
    'remoteModifiedAt': remoteModifiedAt?.toIso8601String(),
    'conflictStatus': conflictStatus.name,
    'isDeleted': isDeleted,
  };

  factory SyncMetadata.fromJson(Map<String, dynamic> json) => SyncMetadata(
    entryUuid: json['entryUuid'] ?? '',
    isSynced: json['isSynced'] ?? false,
    lastSyncedAt: json['lastSyncedAt'] != null
        ? DateTime.tryParse(json['lastSyncedAt'])
        : null,
    localModifiedAt: DateTime.tryParse(json['localModifiedAt'] ?? '') ?? DateTime.now(),
    remoteModifiedAt: json['remoteModifiedAt'] != null
        ? DateTime.tryParse(json['remoteModifiedAt'])
        : null,
    conflictStatus: ConflictStatus.values.firstWhere(
      (e) => e.name == json['conflictStatus'],
      orElse: () => ConflictStatus.none,
    ),
    isDeleted: json['isDeleted'] ?? false,
  );
}

/// 冲突状态枚举
enum ConflictStatus {
  none, // 无冲突
  pending, // 待解决
  resolved, // 已解决
}
