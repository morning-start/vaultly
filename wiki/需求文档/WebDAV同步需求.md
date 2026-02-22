# WebDAV 同步需求文档

> **版本**: v1.2.0  
> **更新日期**: 2026-02-22  
> **作者**: Vaultly Team  
> **文档类型**: 需求文档

---

## 版本历史

| 版本 | 日期 | 修改内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-02-20 | 初始版本 | Vaultly Team |
| v1.1.0 | 2026-02-20 | 补充代码实现映射、完善数据流动细节 | Vaultly Team |
| v1.2.0 | 2026-02-22 | 统一 SyncStatus 枚举和状态定义 | Vaultly Team |

---

## 一、数据模型

### 1.1 核心实体

#### SyncConfig（同步配置）

```dart
class SyncConfig {
  final String id;                    // 配置 ID
  final String serverUrl;             // WebDAV 服务器地址
  final String username;              // 用户名
  final String? password;             // 密码（存储在 Keychain）
  final String? appPassword;          // 应用专用密码
  final String remotePath;            // 远程路径（默认 /vaultly/）
  
  // 同步设置
  final SyncMode syncMode;            // 同步模式
  final Duration autoSyncInterval;    // 自动同步间隔
  final bool syncOnChange;            // 变更时同步
  final bool syncOnStartup;           // 启动时同步
  
  // 状态
  final bool isEnabled;               // 是否启用
  final DateTime? lastSyncAt;         // 最后同步时间
  final SyncStatus lastSyncStatus;    // 最后同步状态
}

enum SyncMode {
  auto,       // 自动双向同步
  manual,     // 仅手动同步
  uploadOnly, // 仅上传（备份模式）
  downloadOnly, // 仅下载（恢复模式）
}

enum SyncStatus {
  idle,           // 空闲
  checking,       // 检查中
  downloading,    // 下载中
  uploading,      // 上传中
  merging,        // 合并中
  conflicted,     // 冲突中
  resolving,      // 解决中
  success,        // 同步成功
  failure,        // 同步失败
  neverSynced,    // 从未同步
}
```

#### SyncState（同步状态）

```dart
class SyncState {
  final SyncStatus status;            // 当前状态
  final double progress;              // 进度（0-100）
  final String? currentOperation;     // 当前操作描述
  final DateTime? startedAt;          // 开始时间
  final DateTime? completedAt;        // 完成时间
  final SyncError? error;             // 错误信息
  final List<Conflict>? conflicts;    // 冲突列表
}

class SyncError {
  final SyncErrorType type;
  final String message;
  final String? details;
}

enum SyncErrorType {
  networkError,       // 网络错误
  authenticationError, // 认证失败
  serverError,        // 服务器错误
  conflictError,      // 冲突错误
  quotaExceeded,      // 配额超限
  unknownError,       // 未知错误
}
```

#### Conflict（冲突）

```dart
class Conflict {
  final String entryId;               // 冲突条目 ID
  final ConflictType type;            // 冲突类型
  final DateTime localModifiedAt;     // 本地修改时间
  final DateTime remoteModifiedAt;    // 远程修改时间
  final VaultEntry? localEntry;       // 本地条目
  final VaultEntry? remoteEntry;      // 远程条目
}

enum ConflictType {
  localModified,      // 仅本地修改
  remoteModified,     // 仅远程修改
  bothModified,       // 双方都修改
  localDeleted,       // 本地删除
  remoteDeleted,      // 远程删除
}
```

#### RemoteVault（远程保险库）

```dart
class RemoteVault {
  final String version;               // 数据版本
  final DateTime modifiedAt;          // 修改时间
  final String checksum;              // 数据校验和
  final int entryCount;               // 条目数量
  final int size;                     // 文件大小（字节）
}
```

### 1.2 数据字典

| 字段名 | 类型 | 长度 | 必填 | 说明 |
|--------|------|------|------|------|
| serverUrl | String | 2048 | ✅ | WebDAV 服务器 URL |
| username | String | 256 | ✅ | 登录用户名 |
| remotePath | String | 512 | ✅ | 默认 /vaultly/ |
| syncMode | Enum | - | ✅ | 默认 auto |
| autoSyncInterval | Duration | - | ❌ | 自动同步间隔 |
| isEnabled | Bool | - | ✅ | 默认 false |

---

## 二、数据流动

### 2.1 配置 WebDAV 连接数据流

```mermaid
sequenceDiagram
    participant User as 用户
    participant UI as 设置界面
    participant SyncService as 同步服务
    participant WebDAVClient as WebDAV 客户端
    participant Keychain as 安全存储

    User->>UI: 输入服务器信息
    UI->>SyncService: testConnection(config)
    
    SyncService->>WebDAVClient: connect(serverUrl, credentials)
    WebDAVClient->>WebDAVClient: 发送 PROPFIND 请求
    
    alt 连接失败
        WebDAVClient-->>SyncService: 错误响应
        SyncService-->>UI: ConnectionResult.failure
        UI-->>User: 显示错误信息
    else 连接成功
        WebDAVClient-->>SyncService: 成功响应
        SyncService->>Keychain: saveCredentials(credentials)
        SyncService->>SyncService: saveConfig(config)
        SyncService-->>UI: ConnectionResult.success
        UI-->>User: 显示连接成功
    end
```

### 2.2 执行同步数据流

```mermaid
sequenceDiagram
    participant User as 用户/App
    participant SyncService as 同步服务
    participant CryptoService as 加密服务
    participant WebDAVClient as WebDAV 客户端
    participant Isar as 本地数据库
    participant Remote as WebDAV 服务器

    User->>SyncService: sync()
    SyncService->>SyncService: 设置状态为 syncing
    
    SyncService->>WebDAVClient: getRemoteVaultInfo()
    WebDAVClient->>Remote: PROPFIND /vaultly/vault.enc
    Remote-->>WebDAVClient: 远程文件信息
    WebDAVClient-->>SyncService: RemoteVault
    
    SyncService->>Isar: getLocalVaultInfo()
    Isar-->>SyncService: LocalVault
    
    SyncService->>SyncService: compareVersions()
    
    alt 无需同步
        SyncService-->>User: 同步完成（无需更新）
    else 需要下载
        SyncService->>WebDAVClient: downloadVault()
        WebDAVClient->>Remote: GET /vaultly/vault.enc
        Remote-->>WebDAVClient: 加密数据
        WebDAVClient-->>SyncService: encryptedData
        
        SyncService->>CryptoService: decrypt(encryptedData, vaultKey)
        CryptoService-->>SyncService: vaultData
        
        SyncService->>SyncService: mergeWithLocal()
        SyncService->>Isar: updateLocalVault()
    else 需要上传
        SyncService->>Isar: getLocalVault()
        Isar-->>SyncService: localData
        
        SyncService->>CryptoService: encrypt(localData, vaultKey)
        CryptoService-->>SyncService: encryptedData
        
        SyncService->>WebDAVClient: uploadVault(encryptedData)
        WebDAVClient->>Remote: PUT /vaultly/vault.enc
        Remote-->>WebDAVClient: 成功响应
    else 冲突
        SyncService->>SyncService: detectConflicts()
        SyncService-->>User: 显示冲突列表
        
        User->>SyncService: resolveConflicts(resolutions)
        SyncService->>SyncService: applyResolutions()
        SyncService->>SyncService: 重新同步
    end
    
    SyncService->>SyncService: 更新同步状态
    SyncService-->>User: 同步完成
```

### 2.3 冲突解决数据流

```mermaid
sequenceDiagram
    participant User as 用户
    participant UI as 冲突解决界面
    participant SyncService as 同步服务
    participant Isar as 本地数据库
    participant WebDAVClient as WebDAV 客户端

    SyncService->>SyncService: detectConflicts()
    SyncService->>UI: 显示冲突列表
    
    loop 每个冲突
        UI->>User: 显示冲突详情
        User->>UI: 选择解决方案
        
        alt 保留本地
            UI->>SyncService: resolve(keepLocal)
        else 保留远程
            UI->>SyncService: resolve(keepRemote)
        else 合并
            UI->>SyncService: resolve(merge)
        end
    end
    
    SyncService->>SyncService: applyAllResolutions()
    
    alt 有本地优先的冲突
        SyncService->>Isar: 更新本地数据
        SyncService->>SyncService: 触发上传
    end
    
    SyncService-->>UI: 冲突解决完成
    UI-->>User: 返回同步状态
```

---

## 三、状态管理

### 3.1 同步状态机

```mermaid
stateDiagram-v2
    [*] --> 未配置: 初始状态
    
    未配置 --> 已配置: 配置完成
    已配置 --> 连接中: 测试连接
    连接中 --> 连接成功: 连接正常
    连接中 --> 连接失败: 连接错误
    连接失败 --> 连接中: 重试
    
    连接成功 --> 空闲: 等待同步
    空闲 --> 检查中: 开始同步
    
    检查中 --> 下载中: 需要下载
    检查中 --> 上传中: 需要上传
    检查中 --> 空闲: 无需同步
    检查中 --> 冲突中: 检测到冲突
    
    下载中 --> 合并中: 下载完成
    合并中 --> 空闲: 合并完成
    
    上传中 --> 空闲: 上传完成
    
    冲突中 --> 解决中: 开始解决
    解决中 --> 上传中: 解决完成（需上传）
    解决中 --> 下载中: 解决完成（需下载）
    
    下载中 --> 错误: 下载失败
    上传中 --> 错误: 上传失败
    错误 --> 空闲: 恢复
```

### 3.2 状态定义

| 状态 | 说明 | 允许的操作 |
|------|------|-----------|
| 未配置 | 未设置 WebDAV | 配置连接 |
| 已配置 | 已配置但未测试 | 测试连接 |
| 连接中 | 正在测试连接 | 取消 |
| 连接成功 | 连接正常 | 开始同步 |
| 连接失败 | 连接错误 | 重试、修改配置 |
| 空闲 | 等待同步 | 手动同步 |
| 检查中 | 检查版本差异 | - |
| 无需同步 | 版本一致 | - |
| 下载中 | 正在下载 | 取消 |
| 上传中 | 正在上传 | 取消 |
| 合并中 | 合并数据 | - |
| 冲突中 | 检测到冲突 | 解决冲突 |
| 解决中 | 正在解决冲突 | - |
| 错误 | 同步错误 | 重试、查看错误 |

### 3.3 状态转换表

| 当前状态 | 事件 | 目标状态 | 动作 |
|---------|------|---------|------|
| 未配置 | CONFIGURE | 已配置 | 保存配置 |
| 已配置 | TEST_CONNECTION | 连接中 | 测试连接 |
| 连接中 | CONNECTION_SUCCESS | 连接成功 | - |
| 连接中 | CONNECTION_FAILURE | 连接失败 | 记录错误 |
| 连接成功 | START_SYNC | 检查中 | 检查版本 |
| 检查中 | NEED_DOWNLOAD | 下载中 | 开始下载 |
| 检查中 | NEED_UPLOAD | 上传中 | 开始上传 |
| 检查中 | NO_CHANGES | 无需同步 | - |
| 无需同步 | COMPLETE | 空闲 | 更新状态 |
| 检查中 | CONFLICT_DETECTED | 冲突中 | 记录冲突 |
| 下载中 | DOWNLOAD_COMPLETE | 合并中 | 合并数据 |
| 合并中 | MERGE_COMPLETE | 空闲 | 更新本地 |
| 上传中 | UPLOAD_COMPLETE | 空闲 | 更新状态 |
| 冲突中 | START_RESOLVE | 解决中 | 显示冲突 |
| 解决中 | RESOLUTION_COMPLETE | 上传中/下载中 | 应用解决 |

---

## 四、接口设计

### 4.1 SyncService 接口

```dart
abstract class SyncService {
  // 配置管理
  Future<void> saveConfig(SyncConfig config);
  Future<SyncConfig?> getConfig();
  Future<void> deleteConfig();
  
  // 连接测试
  Future<ConnectionResult> testConnection(SyncConfig config);
  
  // 同步操作
  Future<SyncResult> sync();
  Future<SyncResult> syncUpload();
  Future<SyncResult> syncDownload();
  
  // 状态查询
  Stream<SyncState> get syncStateStream;
  SyncState get currentState;
  bool get isSyncing;
  
  // 冲突解决
  Future<void> resolveConflict(String entryId, ConflictResolution resolution);
  Future<void> resolveAllConflicts(Map<String, ConflictResolution> resolutions);
  
  // 历史记录
  Future<List<SyncHistory>> getSyncHistory({int limit = 50});
  Future<void> clearSyncHistory();
}

enum ConflictResolution {
  keepLocal,    // 保留本地
  keepRemote,   // 保留远程
  merge,        // 合并
  skip,         // 跳过
}
```

### 4.2 WebDAVClient 接口

```dart
abstract class WebDAVClient {
  // 连接
  Future<void> connect(String url, String username, String password);
  Future<void> disconnect();
  
  // 文件操作
  Future<bool> fileExists(String path);
  Future<RemoteFile> getFileInfo(String path);
  Future<Uint8List> downloadFile(String path);
  Future<void> uploadFile(String path, Uint8List data);
  Future<void> deleteFile(String path);
  
  // 目录操作
  Future<void> createDirectory(String path);
  Future<List<RemoteFile>> listDirectory(String path);
}

class RemoteFile {
  final String path;
  final String name;
  final int size;
  final DateTime modifiedAt;
  final bool isDirectory;
}
```

---

## 五、缓存策略

### 5.1 本地缓存

| 数据 | 缓存位置 | 策略 | 说明 |
|------|---------|------|------|
| 同步配置 | Isar + Keychain | 持久化 | 配置信息 |
| 最后同步状态 | Isar | 持久化 | 同步历史 |
| 远程文件信息 | 内存 | 同步时更新 | 临时缓存 |
| 冲突列表 | 内存 | 解决后清除 | 临时数据 |

### 5.2 同步策略

| 策略 | 触发条件 | 行为 |
|------|---------|------|
| 即时同步 | 条目变更后 | 延迟 5s 后同步 |
| 定时同步 | 每 N 分钟 | 检查并同步 |
| 启动同步 | 应用启动 | 检查远程变更 |
| 手动同步 | 用户触发 | 立即同步 |

---

## 六、安全考虑

### 6.1 传输安全

| 措施 | 实现 | 说明 |
|------|------|------|
| HTTPS 强制 | 仅允许 HTTPS URL | 防止中间人攻击 |
| 证书校验 | 验证服务器证书 | 防止伪造 |
| 凭证安全 | Keychain 存储 | 系统级保护 |

### 6.2 数据安全

| 措施 | 实现 | 说明 |
|------|------|------|
| 端到端加密 | 上传前加密 | 服务器无法解密 |
| 完整性校验 | SHA-256 校验和 | 检测数据损坏 |
| 版本控制 | 保留历史版本 | 防止数据丢失 |

---

## 七、代码实现映射

### 7.1 数据模型实现

```dart
// lib/core/models/sync_metadata.dart
class SyncMetadata {
  final String id;
  final String serverUrl;
  final String username;
  final String remotePath;
  final SyncMode syncMode;
  final bool isEnabled;
  final DateTime? lastSyncAt;
  final SyncStatus lastSyncStatus;
  
  SyncMetadata({
    required this.id,
    required this.serverUrl,
    required this.username,
    this.remotePath = '/vaultly/',
    this.syncMode = SyncMode.auto,
    this.isEnabled = false,
    this.lastSyncAt,
    this.lastSyncStatus = SyncStatus.neverSynced,
  });
}

enum SyncMode { auto, manual, uploadOnly, downloadOnly }
enum SyncStatus { success, failure, conflict, inProgress, neverSynced }
```

### 7.2 同步服务实现

```dart
// lib/core/services/webdav_service.dart
class WebDAVService {
  final WebDAVClient _client;
  final VaultRepository _vaultRepository;
  final CryptoService _cryptoService;
  final LocalStorageRepository _storage;
  
  // 测试连接
  Future<ConnectionResult> testConnection(SyncConfig config) async {
    try {
      await _client.connect(
        config.serverUrl,
        config.username,
        config.password,
      );
      
      // 测试 PROPFIND 请求
      await _client.listDirectory(config.remotePath);
      
      return ConnectionResult.success();
    } on WebDAVException catch (e) {
      return ConnectionResult.failure(e.message);
    }
  }
  
  // 执行同步
  Future<SyncResult> sync() async {
    final config = await _storage.getSyncConfig();
    if (config == null || !config.isEnabled) {
      return SyncResult.failure('Sync not configured');
    }
    
    try {
      // 获取远程信息
      final remoteFile = await _client.getFileInfo(
        '${config.remotePath}/vault.enc',
      );
      
      // 获取本地数据
      final localEntries = await _vaultRepository.getAllEntries();
      final localChecksum = CryptoService.calculateChecksum(localEntries);
      
      // 比较校验和
      if (remoteFile.etag == localChecksum) {
        return SyncResult.noChanges();
      }
      
      // 下载并合并
      final encryptedData = await _client.downloadFile(
        '${config.remotePath}/vault.enc',
      );
      
      final decryptedJson = await _cryptoService.decrypt(
        encryptedData,
        await _getVaultKey(),
      );
      
      final remoteEntries = _parseEntries(decryptedJson);
      final mergedEntries = await _mergeEntries(localEntries, remoteEntries);
      
      // 保存合并结果
      await _vaultRepository.saveAllEntries(mergedEntries);
      
      // 上传合并后的数据
      final newEncryptedData = await _cryptoService.encrypt(
        jsonEncode(mergedEntries),
        await _getVaultKey(),
      );
      
      await _client.uploadFile(
        '${config.remotePath}/vault.enc',
        newEncryptedData,
      );
      
      // 更新同步时间
      await _storage.updateLastSyncTime(DateTime.now());
      
      return SyncResult.success();
    } catch (e) {
      return SyncResult.failure(e.toString());
    }
  }
}
```

### 7.3 状态管理实现

```dart
// lib/core/providers/webdav_provider.dart
@riverpod
class WebDAVNotifier extends _$WebDAVNotifier {
  @override
  WebDAVState build() {
    return WebDAVState();
  }
  
  Future<void> configure(SyncConfig config) async {
    state = state.copyWith(isLoading: true);
    
    final result = await ref.read(webDAVServiceProvider).testConnection(config);
    
    result.when(
      success: () {
        state = state.copyWith(
          isLoading: false,
          config: config,
          isConnected: true,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error,
          isConnected: false,
        );
      },
    );
  }
  
  Future<void> sync() async {
    state = state.copyWith(isSyncing: true, error: null);
    
    final result = await ref.read(webDAVServiceProvider).sync();
    
    result.when(
      success: () => state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        lastSyncStatus: SyncStatus.success,
      ),
      failure: (error) => state = state.copyWith(
        isSyncing: false,
        error: error,
        lastSyncStatus: SyncStatus.failure,
      ),
      noChanges: () => state = state.copyWith(isSyncing: false),
    );
  }
}
```

### 7.4 关键实现文件映射

| 文档概念 | 实现文件 | 说明 |
|----------|----------|------|
| **SyncConfig** | `lib/core/models/sync_metadata.dart` | 同步配置模型 |
| **SyncState** | `lib/core/providers/webdav_provider.dart` | 同步状态管理 |
| **WebDAVService** | `lib/core/services/webdav_service.dart` | 同步业务逻辑 |
| **WebDAVClient** | `lib/core/services/webdav_client.dart` | WebDAV 客户端 |
| **Conflict** | `lib/core/models/sync_metadata.dart` | 冲突数据模型 |

---

## 八、相关文档

### 8.1 渐进式文档链
- [WebDAV 同步功能文档](../功能文档/WebDAV同步功能.md) - 功能需求、用户场景
- [同步架构](../02-架构设计/同步架构.md) - 技术选型、实现方案

### 8.2 状态机与数据流
- [同步状态机](../状态机/同步状态机.md) - 状态转换设计
- [用户登录数据流](../数据流动/用户登录数据流.md) - 数据流动设计参考

### 8.3 模块设计
- [同步模块](../03-模块设计/同步模块.md) - 详细模块设计
- [同步架构](../02-架构设计/同步架构.md) - 同步架构设计

---

## 九、变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.1.0 | 2026-02-20 | 补充代码实现映射、完善数据流动细节 | Vaultly Team |
| v1.0.0 | 2026-02-20 | 初始版本 | Vaultly Team |
