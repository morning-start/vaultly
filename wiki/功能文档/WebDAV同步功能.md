# WebDAV 同步功能

> **版本**: v1.3.0  
> **更新日期**: 2026-02-22  
> **作者**: Vaultly Team  
> **文档类型**: 功能文档

---

## 版本历史

| 版本 | 日期 | 修改内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-02-20 | 初始版本 | Vaultly Team |
| v1.1.0 | 2026-02-20 | 补充代码实现映射、完善验收标准 | Vaultly Team |
| v1.2.0 | 2026-02-22 | 明确加密流程：数据必须经过主密码加密，支持压缩 | Vaultly Team |
| v1.3.0 | 2026-02-22 | 新增加密开关选项：用户可选择是否加密，默认加密 | Vaultly Team |

---

## 一、功能概述

### 1.1 功能描述

WebDAV 同步功能允许用户将加密的保险库数据同步到自建的 WebDAV 服务器（如 Nextcloud、Synology、ownCloud），实现多设备数据同步。采用端到端加密设计，服务器仅存储加密数据，无法解密用户内容。

### 1.2 安全设计原则

#### 核心安全要求

1. **端到端加密（默认）**：所有同步到云端的数据默认经过加密，服务器仅存储密文
2. **主密码派生**：加密密钥必须从用户主密码派生，确保只有用户能解密
3. **可选压缩**：同步前可选择压缩数据，减少传输体积
4. **用户可控**：用户可自主选择是否加密（不加密时使用原始 JSON 格式）

#### 加密模式选项

| 模式 | 说明 | 文件格式 | 安全性 |
|------|------|---------|--------|
| **加密（默认）** | 使用主密码加密后传输 | `.enc` 或 `.json.gz` | 高 |
| **不加密** | 原始 JSON 格式传输 | `.json` | 低 |

#### 加密流程（默认模式）

```
用户主密码
     ↓
  Argon2id 密钥派生
     ↓
  AES-256-GCM 加密
     ↓ (可选)
  GZIP 压缩
     ↓
  WebDAV 服务器
```

#### 非加密流程（可选模式）

```
保险库数据 (JSON)
     ↓ (可选)
  GZIP 压缩
     ↓
  WebDAV 服务器
```

#### 解密流程（默认模式）

```
WebDAV 服务器
     ↓ (可选)
  GZIP 解压
     ↓
  AES-256-GCM 解密
     ↓
  Argon2id 密钥验证
     ↓
  保险库数据
```

### 1.3 用户场景

#### 场景 1：首次配置同步
> 作为用户，我希望将保险库同步到我的 NAS，以便在手机和电脑间共享数据。

**用户旅程：**
1. 进入设置 → 同步设置
2. 选择 WebDAV 同步
3. 输入服务器地址、用户名、密码
4. 点击"测试连接"
5. 连接成功后启用自动同步
6. 系统提示：数据将使用主密码加密后同步

#### 场景 2：手动同步
> 作为用户，我希望在修改密码后立即同步到服务器。

**用户旅程：**
1. 在保险库主页点击同步按钮
2. 系统要求验证主密码（确保会话有效）
3. 数据经过主密码加密
4. (可选) 压缩加密数据
5. 上传到 WebDAV
6. 显示同步成功提示

#### 场景 3：多设备同步
> 作为用户，我在手机上添加了新密码，希望在电脑上也能看到。

**用户旅程：**
1. 手机上添加新条目
2. 自动/手动同步到 WebDAV（加密后上传）
3. 电脑上打开应用
4. 输入主密码解锁保险库
5. 自动检测远程变更
6. 下载并解密数据
7. 新条目出现在电脑上

#### 场景 4：处理冲突
> 作为用户，我在两台设备上同时修改了同一条目，希望保留正确的版本。

**用户旅程：**
1. 设备 A 修改条目并同步
2. 设备 B 修改同一条目并尝试同步
3. 系统检测到冲突（通过版本号比较）
4. 提示用户选择：保留本地、保留远程、合并
5. 用户选择后完成同步

---

## 二、功能需求

### 2.1 功能清单

| 功能 ID | 功能名称 | 优先级 | 描述 |
|---------|---------|--------|------|
| SYNC-001 | WebDAV 配置 | P0 | 配置服务器连接信息 |
| SYNC-002 | 连接测试 | P0 | 验证 WebDAV 连接 |
| SYNC-003 | 手动同步 | P0 | 手动触发上传/下载 |
| SYNC-004 | 自动同步 | P0 | 变更后自动同步 |
| SYNC-005 | 冲突检测 | P0 | 检测本地/远程冲突 |
| SYNC-006 | 冲突解决 | P0 | 提供冲突解决界面 |
| SYNC-007 | 同步历史 | P1 | 查看同步记录 |
| SYNC-008 | 增量同步 | P1 | 仅同步变更部分 |
| SYNC-009 | 同步计划 | P2 | 定时同步设置 |
| SYNC-010 | 多服务器 | P2 | 支持多个同步目标 |
| SYNC-011 | 加密开关 | P0 | 用户可选择是否加密传输（默认加密）|
| SYNC-012 | 压缩开关 | P1 | 用户可选择是否压缩传输（默认压缩）|

### 2.2 同步策略

| 策略 | 说明 | 适用场景 |
|------|------|---------|
| 完整同步 | 上传/下载整个保险库文件 | 首次同步、强制同步 |
| 增量同步 | 仅同步变更的条目 | 日常同步（未来版本）|
| 双向同步 | 合并本地和远程变更 | 常规同步 |
| 仅上传 | 只上传本地变更 | 备份模式 |
| 仅下载 | 只下载远程变更 | 恢复模式 |

### 2.3 支持的 WebDAV 服务

| 服务 | 兼容性 | 测试状态 |
|------|--------|---------|
| Nextcloud | ✅ 完全支持 | 已测试 |
| ownCloud | ✅ 完全支持 | 已测试 |
| Synology NAS | ✅ 完全支持 | 已测试 |
| QNAP NAS | ✅ 支持 | 待测试 |
| 坚果云 | ⚠️ 有限支持 | 待测试 |
| Box | ⚠️ 有限支持 | 待测试 |

---

## 三、用户界面

### 3.1 界面清单

| 界面 | 描述 | 关键元素 |
|------|------|---------|
| 同步设置 | 配置 WebDAV | 服务器地址、账号、密码、加密开关、压缩开关、测试按钮 |
| 同步状态 | 显示同步状态 | 最后同步时间、状态图标、手动同步按钮 |
| 冲突解决 | 处理冲突 | 本地/远程对比、选择按钮 |
| 同步历史 | 查看记录 | 同步时间、结果、详情 |

### 3.2 界面原型

```
┌─────────────────────────────┐
│ ← 同步设置                  │
├─────────────────────────────┤
│                             │
│ 服务器地址                  │
│ ┌─────────────────────────┐ │
│ │ https://nextcloud.com   │ │
│ └─────────────────────────┘ │
│                             │
│ 用户名                      │
│ ┌─────────────────────────┐ │
│ │ user@example.com        │ │
│ └─────────────────────────┘ │
│                             │
│ 密码/应用密码               │
│ ┌─────────────────────────┐ │
│ │ ****************        │ │
│ └─────────────────────────┘ │
│                             │
│     ┌───────────────┐       │
│     │  测试连接     │       │
│     └───────────────┘       │
│                             │
│ ✅ 连接成功                 │
│                             │
│ 同步设置                    │
│ ☑️ 自动同步（推荐）         │
│ ○ 仅手动同步                │
│                             │
│ 同步频率                    │
│ 每次变更后立即同步    ▼     │
│                             │
└─────────────────────────────┘
```

---

## 四、验收标准

### 4.1 功能验收

| 验收项 | 验收标准 | 测试方法 |
|--------|---------|---------|
| WebDAV 连接 | 支持标准 WebDAV 协议 | 集成测试 |
| 上传功能 | 加密数据成功上传到服务器 | 端到端测试 |
| 下载功能 | 从服务器下载并解密数据 | 端到端测试 |
| 冲突检测 | 正确识别本地/远程冲突 | 单元测试 |
| 冲突解决 | 用户选择后正确合并 | 集成测试 |
| 自动同步 | 变更后自动触发同步 | 手动测试 |

### 4.2 性能验收

| 指标 | 目标值 | 测量方法 |
|------|--------|---------|
| 连接建立 | < 3s | 性能测试 |
| 上传时间 | < 5s（< 1MB） | 性能测试 |
| 下载时间 | < 5s（< 1MB） | 性能测试 |
| 冲突检测 | < 1s | 性能测试 |

### 4.3 安全验收

| 验收项 | 验收标准 |
|--------|---------|
| 端到端加密 | 上传前数据已加密，服务器无法解密 |
| 传输安全 | 仅允许 HTTPS 连接 |
| 凭证安全 | WebDAV 密码安全存储在系统钥匙串 |
| 完整性校验 | 同步数据包含完整性校验和 |

---

## 五、代码实现映射

### 5.1 核心实现文件

| 功能 | 实现文件 | 关键类/方法 |
|------|----------|-------------|
| **同步服务** | `lib/core/services/webdav_service.dart` | `WebDAVService` |
| **WebDAV 客户端** | `lib/core/services/webdav_client.dart` | `WebDAVClient` |
| **同步配置** | `lib/core/models/sync_metadata.dart` | `SyncMetadata` |
| **同步状态管理** | `lib/core/providers/webdav_provider.dart` | `WebDAVNotifier` |
| **同步配置页面** | `lib/ui/pages/webdav_config_page.dart` | `WebDAVConfigPage` |
| **同步状态页面** | `lib/ui/pages/webdav_sync_page.dart` | `WebDAVSyncPage` |

### 5.2 同步服务实现

```dart
// lib/core/services/webdav_service.dart
class WebDAVService {
  final WebDAVClient _client;
  final VaultRepository _vaultRepository;
  final CryptoService _cryptoService;
  
  // 执行同步
  Future<SyncResult> sync() async {
    try {
      // 1. 获取远程文件信息
      final remoteInfo = await _client.getFileInfo('/vaultly/vault.enc');
      
      // 2. 获取本地数据
      final localData = await _vaultRepository.getAllEntries();
      final localChecksum = CryptoService.calculateChecksum(localData);
      
      // 3. 比较版本
      if (remoteInfo.checksum == localChecksum) {
        return SyncResult.noChanges;
      }
      
      // 4. 下载远程数据
      final encryptedData = await _client.downloadFile('/vaultly/vault.enc');
      
      // 5. 解密远程数据
      final remoteData = await _cryptoService.decrypt(
        encryptedData,
        await _getVaultKey(),
      );
      
      // 6. 合并数据
      final mergedData = await _mergeData(localData, remoteData);
      
      // 7. 加密并上传
      final newEncryptedData = await _cryptoService.encrypt(
        jsonEncode(mergedData),
        await _getVaultKey(),
      );
      
      await _client.uploadFile('/vaultly/vault.enc', newEncryptedData);
      
      return SyncResult.success;
    } catch (e) {
      return SyncResult.failure(e.toString());
    }
  }
}
```

### 5.3 状态管理实现

```dart
// lib/core/providers/webdav_provider.dart
class WebDAVNotifier extends StateNotifier<WebDAVState> {
  final WebDAVService _webDAVService;
  
  Future<void> sync() async {
    state = state.copyWith(isSyncing: true, error: null);
    
    final result = await _webDAVService.sync();
    
    result.when(
      success: () => state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
      ),
      failure: (error) => state = state.copyWith(
        isSyncing: false,
        error: error,
      ),
      noChanges: () => state = state.copyWith(isSyncing: false),
    );
  }
}
```

---

## 六、相关文档

### 6.1 渐进式文档链
- [WebDAV 同步需求文档](../需求文档/WebDAV同步需求.md) - 数据模型、数据流动、状态管理
- [同步架构](../02-架构设计/同步架构.md) - 技术选型、实现方案

### 6.2 状态机与数据流
- [同步状态机](../状态机/同步状态机.md) - 状态转换设计
- [用户登录数据流](../数据流动/用户登录数据流.md) - 数据流动设计参考

### 6.3 模块设计
- [同步模块](../03-模块设计/同步模块.md) - 详细模块设计
- [同步架构](../02-架构设计/同步架构.md) - 同步架构设计

---

## 七、变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.1.0 | 2026-02-20 | 补充代码实现映射、完善验收标准 | Vaultly Team |
| v1.0.0 | 2026-02-20 | 初始版本 | Vaultly Team |
