// 同步模块数据模型
//
// 参考文档: wiki/03-模块设计/同步模块.md

/// 同步配置
class SyncConfig {
  final String id;
  final String serverUrl;
  final String username;
  final String? password;
  final String? appPassword;
  final String remotePath;
  final SyncMode syncMode;
  final Duration autoSyncInterval;
  final bool syncOnChange;
  final bool syncOnStartup;
  final bool isEnabled;
  final DateTime? lastSyncAt;
  final SyncStatus lastSyncStatus;

  SyncConfig({
    required this.id,
    required this.serverUrl,
    required this.username,
    this.password,
    this.appPassword,
    this.remotePath = '/vaultly/',
    this.syncMode = SyncMode.manual,
    this.autoSyncInterval = const Duration(minutes: 30),
    this.syncOnChange = false,
    this.syncOnStartup = false,
    this.isEnabled = true,
    this.lastSyncAt,
    this.lastSyncStatus = SyncStatus.idle,
  });

  SyncConfig copyWith({
    String? id,
    String? serverUrl,
    String? username,
    String? password,
    String? appPassword,
    String? remotePath,
    SyncMode? syncMode,
    Duration? autoSyncInterval,
    bool? syncOnChange,
    bool? syncOnStartup,
    bool? isEnabled,
    DateTime? lastSyncAt,
    SyncStatus? lastSyncStatus,
  }) {
    return SyncConfig(
      id: id ?? this.id,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      appPassword: appPassword ?? this.appPassword,
      remotePath: remotePath ?? this.remotePath,
      syncMode: syncMode ?? this.syncMode,
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      syncOnChange: syncOnChange ?? this.syncOnChange,
      syncOnStartup: syncOnStartup ?? this.syncOnStartup,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
    );
  }

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      id: json['id'] as String,
      serverUrl: json['serverUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String?,
      appPassword: json['appPassword'] as String?,
      remotePath: json['remotePath'] as String? ?? '/vaultly/',
      syncMode: SyncMode.values.firstWhere(
        (e) => e.name == json['syncMode'],
        orElse: () => SyncMode.manual,
      ),
      autoSyncInterval: Duration(minutes: json['autoSyncIntervalMinutes'] as int? ?? 30),
      syncOnChange: json['syncOnChange'] as bool? ?? false,
      syncOnStartup: json['syncOnStartup'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      lastSyncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['lastSyncStatus'],
        orElse: () => SyncStatus.idle,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'appPassword': appPassword,
    'remotePath': remotePath,
    'syncMode': syncMode.name,
    'autoSyncIntervalMinutes': autoSyncInterval.inMinutes,
    'syncOnChange': syncOnChange,
    'syncOnStartup': syncOnStartup,
    'isEnabled': isEnabled,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'lastSyncStatus': lastSyncStatus.name,
  };
}

/// 同步模式
enum SyncMode {
  auto,       // 自动双向同步
  manual,     // 仅手动同步
  uploadOnly, // 仅上传（备份模式）
  downloadOnly, // 仅下载（恢复模式）
}

/// 同步状态
enum SyncStatus {
  idle,       // 空闲
  syncing,    // 同步中
  success,    // 同步成功
  failed,     // 同步失败
  conflict,   // 存在冲突
}

/// 同步状态详情
class SyncState {
  final SyncStatus status;
  final String? message;
  final double? progress;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? added;
  final int? updated;
  final int? deleted;
  final List<SyncConflict>? conflicts;

  SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.progress,
    this.startTime,
    this.endTime,
    this.added,
    this.updated,
    this.deleted,
    this.conflicts,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    double? progress,
    DateTime? startTime,
    DateTime? endTime,
    int? added,
    int? updated,
    int? deleted,
    List<SyncConflict>? conflicts,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      added: added ?? this.added,
      updated: updated ?? this.updated,
      deleted: deleted ?? this.deleted,
      conflicts: conflicts ?? this.conflicts,
    );
  }

  bool get isSyncing => status == SyncStatus.syncing;
  bool get isSuccess => status == SyncStatus.success;
  bool get isFailed => status == SyncStatus.failed;
  bool get hasConflicts => status == SyncStatus.conflict;
}

/// 同步结果
class SyncResult {
  final bool success;
  final int added;
  final int updated;
  final int deleted;
  final List<SyncConflict> conflicts;
  final DateTime timestamp;
  final String? errorMessage;

  SyncResult({
    required this.success,
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    this.conflicts = const [],
    DateTime? timestamp,
    this.errorMessage,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncResult.success({
    int added = 0,
    int updated = 0,
    int deleted = 0,
  }) {
    return SyncResult(
      success: true,
      added: added,
      updated: updated,
      deleted: deleted,
    );
  }

  factory SyncResult.failure(String errorMessage) {
    return SyncResult(
      success: false,
      errorMessage: errorMessage,
    );
  }

  factory SyncResult.withConflicts(List<SyncConflict> conflicts) {
    return SyncResult(
      success: false,
      conflicts: conflicts,
    );
  }
}

/// 同步冲突
class SyncConflict {
  final String entryId;
  final String entryTitle;
  final ConflictType type;
  final DateTime localModifiedAt;
  final DateTime remoteModifiedAt;

  SyncConflict({
    required this.entryId,
    required this.entryTitle,
    required this.type,
    required this.localModifiedAt,
    required this.remoteModifiedAt,
  });
}

/// 冲突类型
enum ConflictType {
  modifyModify,   // 本地和远程都修改
  deleteModify,   // 本地删除，远程修改
  modifyDelete,   // 本地修改，远程删除
  addAdd,         // 本地和远程都添加相同ID
}

/// 冲突解决策略
enum ConflictResolution {
  keepLocal,    // 保留本地
  keepRemote,   // 保留远程
  merge,        // 合并
  skip,         // 跳过
}

/// 连接结果
class ConnectionResult {
  final bool success;
  final String? errorMessage;
  final ServerInfo? serverInfo;

  ConnectionResult({
    required this.success,
    this.errorMessage,
    this.serverInfo,
  });

  factory ConnectionResult.success([ServerInfo? serverInfo]) {
    return ConnectionResult(
      success: true,
      serverInfo: serverInfo,
    );
  }

  factory ConnectionResult.failure(String errorMessage) {
    return ConnectionResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// 服务器信息
class ServerInfo {
  final String? serverName;
  final String? serverVersion;
  final int? maxFileSize;

  ServerInfo({
    this.serverName,
    this.serverVersion,
    this.maxFileSize,
  });
}

/// 同步历史记录
class SyncHistory {
  final String id;
  final DateTime timestamp;
  final bool success;
  final int added;
  final int updated;
  final int deleted;
  final int conflicts;
  final String? errorMessage;

  SyncHistory({
    required this.id,
    required this.timestamp,
    required this.success,
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    this.conflicts = 0,
    this.errorMessage,
  });

  factory SyncHistory.fromJson(Map<String, dynamic> json) {
    return SyncHistory(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool,
      added: json['added'] as int? ?? 0,
      updated: json['updated'] as int? ?? 0,
      deleted: json['deleted'] as int? ?? 0,
      conflicts: json['conflicts'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'added': added,
    'updated': updated,
    'deleted': deleted,
    'conflicts': conflicts,
    'errorMessage': errorMessage,
  };
}
