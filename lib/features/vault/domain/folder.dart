/// 文件夹模型
class Folder {
  final String uuid;
  String name;
  String? parentUuid;
  DateTime createdAt;
  DateTime updatedAt;

  Folder({
    required this.uuid,
    required this.name,
    this.parentUuid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    uuid: json['uuid'] as String,
    name: json['name'] as String,
    parentUuid: json['parentUuid'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'name': name,
    'parentUuid': parentUuid,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// 更新修改时间
  void touch() {
    updatedAt = DateTime.now();
  }
}
