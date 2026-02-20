/// 同步元数据模型
class SyncMetadata {
  final String entryUuid;
  bool isSynced;
  bool isDeleted;
  DateTime? localModifiedAt;
  DateTime? remoteModifiedAt;

  SyncMetadata({
    required this.entryUuid,
    this.isSynced = false,
    this.isDeleted = false,
    this.localModifiedAt,
    this.remoteModifiedAt,
  });

  factory SyncMetadata.fromJson(Map<String, dynamic> json) => SyncMetadata(
    entryUuid: json['entryUuid'] as String,
    isSynced: json['isSynced'] as bool? ?? false,
    isDeleted: json['isDeleted'] as bool? ?? false,
    localModifiedAt: json['localModifiedAt'] != null
        ? DateTime.parse(json['localModifiedAt'] as String)
        : null,
    remoteModifiedAt: json['remoteModifiedAt'] != null
        ? DateTime.parse(json['remoteModifiedAt'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'entryUuid': entryUuid,
    'isSynced': isSynced,
    'isDeleted': isDeleted,
    'localModifiedAt': localModifiedAt?.toIso8601String(),
    'remoteModifiedAt': remoteModifiedAt?.toIso8601String(),
  };
}
