---
project: vaultly
version: 2.4.1
type: data-models
author: auto-generated
date: 2026-06-04
status: stable
---

# Vaultly - 数据模型文档

## 1. 模型总览

```
Models
├── VaultEntry (基类)
│   ├── LoginEntry        (登录凭证)
│   ├── BankCardEntry     (银行卡)
│   ├── SecureNoteEntry   (安全笔记)
│   └── IdentityEntry     (身份信息)
├── Folder                (文件夹)
├── CustomField           (自定义字段)
├── SyncConfig            (同步配置)
├── SyncState             (同步状态)
├── SyncResult            (同步结果)
├── SyncConflict          (同步冲突)
├── SyncHistory           (同步历史)
└── EncryptedData / KeyMaterial (加密相关)
```

## 2. 保险库条目模型 (Vault Entry)

### 2.1 基类: VaultEntry

```dart
class VaultEntry {
  final String id;                    // UUID, 主键
  String title;                       // 标题 (明文, 可搜索)
  final DateTime createdAt;           // 创建时间
  DateTime updatedAt;                 // 最后修改时间
  final EntryType type;               // 条目类型
  List<CustomField> customFields;     // 自定义字段列表
  List<String> tags;                  // 标签列表
  bool isFavorite;                    // 是否收藏
  String? folderId;                   // 所属文件夹 UUID
}
```

### 2.2 条目类型枚举

```dart
enum EntryType {
  login,       // 登录凭证
  bankCard,    // 银行卡
  secureNote,  // 安全笔记
  identity,    // 身份信息
  custom,      // 自定义
}
```

### 2.3 LoginEntry (登录凭证)

| 字段 | 类型 | 加密 | 说明 |
|------|------|------|------|
| username | String? | AES-GCM | 用户名 |
| email | String? | AES-GCM | 电子邮箱 |
| password | String? | AES-GCM | 密码 |
| url | String? | - | 网站 URL |
| totpSecret | String? | AES-GCM | TOTP 共享密钥 (Base32) |
| notes | String? | AES-GCM | 备注信息 |

**继承自 VaultEntry 的字段**: id, title, createdAt, updatedAt, type (=login), customFields, tags, isFavorite, folderId

### 2.4 BankCardEntry (银行卡)

| 字段 | 类型 | 加密 | 说明 |
|------|------|------|------|
| cardNumber | String? | AES-GCM | 卡号 |
| cardHolderName | String? | - | 持卡人姓名 |
| expiryMonth | int? | - | 到期月 (1-12) |
| expiryYear | int? | - | 到期年 (4位) |
| cvv | String? | AES-GCM | 安全码 |
| bankName | String? | - | 开户银行 |
| cardType | CardType? | - | 卡组织类型 |

**CardType 枚举**:

```dart
enum CardType {
  visa, mastercard, amex, discover, jcb, unionPay, other
}
```

### 2.5 SecureNoteEntry (安全笔记)

| 字段 | 类型 | 加密 | 说明 |
|------|------|------|------|
| content | String? | AES-GCM | 笔记内容 |
| isMarkdown | bool | - | 是否 Markdown 格式 |

### 2.6 IdentityEntry (身份信息)

| 字段 | 类型 | 加密 | 说明 |
|------|------|------|------|
| firstName | String? | - | 名 |
| lastName | String? | - | 姓 |
| middleName | String? | - | 中间名 |
| birthDate | DateTime? | - | 出生日期 |
| idNumber | String? | AES-GCM | 证件号码 |
| address | String? | AES-GCM | 地址 |
| phone | String? | AES-GCM | 电话 |
| email | String? | AES-GCM | 电子邮箱 |

## 3. 自定义字段 (CustomField)

```dart
class CustomField {
  final String name;       // 字段名称
  final String value;      // 字段值
  final FieldType type;    // 字段类型
  final bool isSecret;     // 是否隐藏显示
}
```

**FieldType 枚举**:

```dart
enum FieldType {
  text,    // 文本
  hidden,  // 隐藏文本 (密码样式)
  date,    // 日期
  url,     // 链接
  email,   // 邮箱
  phone,   // 电话
  number,  // 数字
}
```

## 4. 文件夹模型 (Folder)

```dart
class Folder {
  final String uuid;          // 文件夹 UUID (主键)
  String name;                // 文件夹名称
  String? parentUuid;         // 父文件夹 UUID (null = 根级)
  final DateTime createdAt;   // 创建时间
  final DateTime updatedAt;   // 修改时间
}
```

**特点**:
- 支持无限层级嵌套 (通过 parentUuid 关联)
- touch() 方法更新 updatedAt 时间戳

## 5. 同步数据模型

### 5.1 SyncConfig (同步配置)

```dart
class SyncConfig {
  final String id;                        // 配置 ID
  final String serverUrl;                 // WebDAV 服务器地址
  final String username;                  // 用户名
  final String? password;                 // 密码
  final String? appPassword;              // 应用专用密码
  final String remotePath;                // 远程路径 (默认 /vaultly/)
  final SyncMode syncMode;                // 同步模式
  final Duration autoSyncInterval;        // 自动同步间隔
  final bool syncOnChange;                // 变更时同步
  final bool syncOnStartup;               // 启动时同步
  final bool isEnabled;                   // 是否启用
  final DateTime? lastSyncAt;             // 最后同步时间
  final SyncStatus lastSyncStatus;        // 最后同步状态
  final bool enableEncryption;            // 启用加密传输
  final bool enableCompression;           // 启用 GZIP 压缩
}
```

### 5.2 SyncState (同步状态详情)

```dart
class SyncState {
  final SyncStatus status;       // 当前状态
  final String? message;         // 状态消息
  final double? progress;        // 进度 (0.0 - 1.0)
  final DateTime? startTime;     // 开始时间
  final DateTime? endTime;       // 结束时间
  final int? added;              // 新增数量
  final int? updated;            // 更新数量
  final int? deleted;            // 删除数量
  final List<SyncConflict>? conflicts; // 冲突列表
}
```

**便捷属性**:
- `isSyncing` → status == SyncStatus.syncing
- `isSuccess` → status == SyncStatus.success
- `isFailed` → status == SyncStatus.failed
- `hasConflicts` → status == SyncStatus.conflict

### 5.3 SyncResult (同步结果)

```dart
class SyncResult {
  final bool success;                    // 是否成功
  final int added;                       // 新增数
  final int updated;                     // 更新数
  final int deleted;                     // 删除数
  final List<SyncConflict> conflicts;    // 冲突列表
  final DateTime timestamp;              // 时间戳
  final String? errorMessage;            // 错误信息
}
```

**工厂构造函数**:
- `SyncResult.success({added, updated, deleted})`
- `SyncResult.failure(errorMessage)`
- `SyncResult.withConflicts(conflicts)`

### 5.4 SyncConflict (同步冲突)

```dart
class SyncConflict {
  final String entryId;           // 冲突条目 ID
  final String entryTitle;        // 条目标题
  final ConflictType type;        // 冲突类型
  final DateTime localModifiedAt; // 本地修改时间
  final DateTime remoteModifiedAt;// 远程修改时间
}
```

**ConflictType 枚举**:

```dart
enum ConflictType {
  modifyModify,   // 两端都修改了同一记录
  deleteModify,   // 本地删除，远程修改
  modifyDelete,   // 本地修改，远程删除
  addAdd,         // 两端添加了相同 ID
}
```

**ConflictResolution 枚举**:

```dart
enum ConflictResolution {
  keepLocal,   // 保留本地版本
  keepRemote,  // 保留远程版本
  merge,       // 合并 (未来实现)
  skip,        // 跳过此冲突
}
```

### 5.5 SyncHistory (同步历史记录)

```dart
class SyncHistory {
  final String id;            // 记录 ID (UUID)
  final DateTime timestamp;   // 同步时间
  final bool success;         // 是否成功
  final int added;            // 新增数
  final int updated;          // 更新数
  final int deleted;          // 删除数
  final int conflicts;        // 冲突数
  final String? errorMessage; // 错误信息
}
```

**存储策略**:
- 最多保留 100 条历史记录
- 按时间倒序排列 (最新在前)

## 6. 加密数据模型

### 6.1 EncryptedData (加密数据)

```dart
class EncryptedData {
  final String cipherText;   // Base64 编码的密文 (不含认证标签)
  final String iv;           // Base64 编码的初始化向量 (12 bytes)
  final String authTag;      // Base64 编码的 GCM 认证标签 (16 bytes)
  final int version;         // 加密协议版本 (当前 = 1)
}
```

**存储大小估算** (每字段):
- IV: 16 bytes (Base64)
- AuthTag: 24 bytes (Base64)
- 密文: ≈ 原文长度 × 4/3 (Base64 开销)
- 总开销: ≈ 原文长度 + 40 bytes (固定开销)

### 6.2 KeyMaterial (密钥材料)

```dart
class KeyMaterial {
  final Uint8List key;       // 派生密钥 (256 bits / 32 bytes)
  final Uint8List salt;      // 使用的盐值 (256 bits / 32 bytes)
  final String hash;         // 用于快速验证的哈希值
  final String algorithm;    // 算法标识 ("argon2id")
  final int version;         // 版本 (2 = Argon2id)
}
```

**便捷属性**:
- `keyBase64` → Base64 编码的密钥
- `saltBase64` → Base64 编码的盐值

## 7. ER 关系图

```
┌─────────────┐       ┌──────────────┐
│   Folder    │       │  VaultEntry  │
├─────────────┤       ├──────────────┤
│ uuid (PK)   │◄──┐   │ id (PK)      │
│ name        │   │   │ title        │
│ parentUuid  │───┘   │ type         │
│ createdAt   │ 1:N   │ folderId(FK) │
│ updatedAt   │       │ createdAt    │
└─────────────┘       │ updatedAt    │
                      │ isFavorite   │
                      ├──────────────┤
                      │ LoginEntry   │
                      │ -username    │
                      │ -password    │
                      │ -email       │
                      │ -url         │
                      │ -totpSecret  │
                      │ -notes       │
                      ├──────────────┤
                      │BankCardEntry │
                      │ -cardNumber  │
                      │ -cvv         │
                      │ -expiry*     │
                      ├──────────────┤
                      │SecureNoteEntry│
                      │ -content     │
                      ├──────────────┤
                      │IdentityEntry │
                      │ -firstName   │
                      │ -lastName    │
                      │ -idNumber    │
                      └──────┬───────┘
                             │
                      ┌──────┴───────┐
                      │ CustomField  │
                      ├──────────────┤
                      │ name         │
                      │ value        │
                      │ type         │
                      │ isSecret     │
                      └──────────────┘

┌─────────────┐       ┌──────────────┐
│  SyncConfig │       │ SyncHistory  │
├─────────────┤       ├──────────────┤
│ id (PK)     │       │ id (PK)      │
│ serverUrl   │       │ timestamp    │
│ username    │       │ success      │
│ password    │       │ added        │
│ syncMode    │       │ updated      │
│ lastSyncAt  │       │ deleted      │
│ ...         │       │ conflicts    │
└─────────────┘       └──────────────┘
```
