---
project: vaultly
version: 2.4.1
type: modules
author: auto-generated
date: 2026-06-04
status: stable
---

# Vaultly - 模块设计文档

## 1. 认证模块 (Authentication Module)

### 1.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/crypto/services/auth_service.dart` |
| 状态管理 | `lib/core/providers/auth_provider.dart` |
| 核心类 | `AuthService`, `AuthNotifier`, `AuthState` |
| 依赖服务 | CryptoService, BiometricService, FlutterSecureStorage |

### 1.2 接口定义

#### AuthService 公开接口

```dart
class AuthService {
  // 状态查询
  bool get isUnlocked;
  Uint8List? get encryptionKey;

  // 密码管理
  Future<bool> isPasswordSet();
  Future<void> setupMasterPassword(String password);
  Future<bool> verifyMasterPassword(String password);
  Future<void> changePassword(String oldPassword, String newPassword);

  // 会话管理
  void lock();

  // 生物识别
  Future<bool> enableBiometric(String password);
  Future<void> disableBiometric();
  Future<bool> isBiometricEnabledByUser();
  Future<bool> biometricUnlock();
  Future<BiometricAvailability> checkBiometricAvailability();

  // 数据管理
  Future<void> clearAllData();
  Future<int> getFailedAttempts();
}
```

#### AuthNotifier 公开接口

```dart
class AuthNotifier extends StateNotifier<AuthState> {
  Future<bool> setupPassword(String password);
  Future<bool> unlock(String password);
  Future<bool> unlockWithBiometric();
  Future<bool> enableBiometric(String password);
  Future<void> disableBiometric();
  void lock();
}
```

### 1.3 状态模型

```dart
class AuthState {
  final bool isUnlocked;              // 是否已解锁
  final bool isPasswordSet;           // 是否已设置密码
  final bool isLoading;               // 是否加载中
  final String? error;                // 错误信息
  final bool biometricAvailable;      // 生物识别是否可用
  final String? biometricTypeName;    // 生物识别类型名称
  final IconData? biometricIcon;      // 生物识别图标
  final bool isAuthenticatingWithBiometric; // 是否正在生物识别认证
}
```

---

## 2. 加密模块 (Cryptography Module)

### 2.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/crypto/services/crypto_service.dart` |
| 核心类 | `CryptoService`, `EncryptedData`, `KeyMaterial` |
| 加密算法 | AES-256-GCM (encrypt 包) |
| KDF 算法 | Argon2id v1.3 (pointycastle) |
| 哈希算法 | SHA-256 (crypto 包) |

### 2.2 接口定义

```dart
class CryptoService {
  // 随机数生成
  static Uint8List generateSalt();           // 32字节随机盐
  static Uint8List generateIV();             // 12字节随机IV
  static Uint8List generateKey();            // 32字节随机密钥

  // 加密/解密
  static EncryptedData encrypt(String plainText, Uint8List key);
  static String decrypt(EncryptedData encryptedData, Uint8List key);

  // 密钥派生
  static Uint8List deriveKeyWithArgon2id(String password, Uint8List salt);
  static KeyMaterial deriveKeyMaterial(String password, Uint8List salt);
  static KeyMaterial generateKeyMaterial(String password);

  // 工具方法
  static String calculateChecksum(List<Map<String, dynamic>> entries);
  static void secureClear(Uint8List data);
  static Map<String, dynamic> getArgon2Params();
}
```

### 2.3 数据结构

```dart
// 加密数据
class EncryptedData {
  final String cipherText;   // Base64 密文
  final String iv;           // Base64 初始向量
  final String authTag;      // Base64 认证标签
  final int version;         // 版本号
}

// 密钥材料
class KeyMaterial {
  final Uint8List key;       // 派生密钥 (256-bit)
  final Uint8List salt;      // 使用的盐值
  final String hash;         // 验证哈希
  final String algorithm;    // 算法标识 ('argon2id')
  final int version;         // 版本 (2=Argon2id)
}
```

---

## 3. 保险库模块 (Vault Module)

### 3.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/services/vault_service.dart` |
| 模型文件 | `lib/core/models/vault_entry.dart` |
| 核心类 | `VaultService` (单例) |
| 存储方式 | FlutterSecureStorage (JSON 格式) |

### 3.2 接口定义

```dart
class VaultService {
  // 单例访问
  static VaultService get instance;

  // 密钥管理
  void setEncryptionKey(Uint8List key);

  // 数据加载/保存
  Future<void> loadVault();
  Future<void> saveVault();

  // CRUD 操作
  Future<String> addEntry(VaultEntry entry);
  Future<void> updateEntry(VaultEntry entry);
  Future<void> deleteEntry(String id);
  Future<VaultEntry?> getEntry(String id);
  Future<List<VaultEntry>> getAllEntries();
  Future<List<VaultEntry>> getEntriesByType(EntryType type);

  // 搜索
  Future<List<VaultEntry>> searchEntries(String query);

  // 收藏管理
  Future<List<VaultEntry>> getFavorites();
  Future<void> toggleFavorite(String entryId);

  // 标签管理
  Future<List<VaultEntry>> getByTag(String tag);
  Future<void> addTag(String entryId, String tag);
  Future<void> removeTag(String entryId, String tag);
  Future<List<String>> getAllTags();

  // 只读访问
  List<VaultEntry> get entries;
}
```

### 3.3 存储格式

保险库数据以 JSON 格式存储在 SecureStorage 中：

```json
{
  "entries": [
    {
      "id": "uuid-string",
      "title": "GitHub",
      "type": "login",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-02T00:00:00.000Z",
      "username": "user@example.com",
      "passwordEncrypted": {
        "cipherText": "Base64...",
        "iv": "Base64...",
        "authTag": "Base64...",
        "version": 1
      },
      "totpSecretEncrypted": { ... },
      "notesEncrypted": { ... },
      "tags": ["work", "dev"],
      "isFavorite": false,
      "customFields": []
    }
  ],
  "updatedAt": "2024-01-02T00:00:00.000Z"
}
```

---

## 4. 同步模块 (Sync Module)

### 4.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/services/webdav_service.dart` |
| 模型文件 | `lib/core/models/sync_models.dart` |
| Provider | `lib/core/providers/webdav_provider.dart` |
| 协议 | WebDAV (RFC 4918) |
| 传输安全 | AES-256-GCM + GZIP (可选) |

### 4.2 接口定义

```dart
class WebDAVService {
  // 配置管理
  Future<bool> isConfigured();
  Future<SyncConfig?> getConfig();
  Future<void> saveConfig(SyncConfig config);
  Future<void> clearConfig();
  Future<ConnectionResult> testConnection(SyncConfig config);

  // 同步操作
  Future<SyncResult> sync({
    required Map<String, dynamic> localVaultData,
    required Uint8List encryptionKey,
    bool? enableEncryption,
    bool? enableCompression,
    Function(double progress)? onProgress,
  });

  // 上传/下载
  Future<bool> upload({...});
  Future<Map<String, dynamic>?> download({...});

  // 状态查询
  Stream<SyncState> get syncStateStream;
  SyncState get currentState;
  bool get isSyncing;
  Future<DateTime?> getLastSyncTime();
  Future<bool> checkRemoteBackup();

  // 冲突解决
  Future<void> resolveConflict(String entryId, ConflictResolution resolution);
  Future<void> resolveAllConflicts(Map<String, ConflictResolution> resolutions);

  // 历史
  Future<List<SyncHistory>> getSyncHistory({int limit});
  Future<void> clearSyncHistory();

  // 缓存
  void clearCache();
  void dispose();
}
```

### 4.3 同步模式枚举

```dart
enum SyncMode {
  auto,          // 自动双向同步
  manual,        // 仅手动同步
  uploadOnly,    // 仅上传（备份）
  downloadOnly,  // 仅下载（恢复）
}

enum SyncStatus {
  idle,          // 空闲
  syncing,       // 同步中
  success,       // 成功
  failed,        // 失败
  conflict,      // 冲突
}

enum ConflictResolution {
  keepLocal,     // 保留本地
  keepRemote,    // 保留远程
  merge,         // 合并
  skip,          // 跳过
}
```

---

## 5. TOTP 模块

### 5.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/services/totp_service.dart` |
| 核心类 | `TOTPService`, `TOTPConfig` |
| 规范遵循 | RFC 6238 / RFC 4226 |
| 算法 | HMAC-SHA1 |

### 5.2 接口定义

```dart
class TOTPService {
  // 生成/验证
  String generateTOTP(String secret, {int digits, int period});
  bool validateTOTP(String code, String secret, {int window, int digits, int period});

  // URI 处理
  TOTPConfig? parseOTPAuthURI(String uri);   // 解析 otpauth://totp/...
  String generateOTPAuthURI(TOTPConfig config); // 生成 URI

  // 工具
  int getRemainingSeconds({int period});      // 当前码剩余秒数
}

class TOTPConfig {
  final String secret;       // Base32 编码密钥
  final String issuer;       // 发行方
  final String accountName;  // 账户名
  final int digits;          // 码长 (默认6)
  final int period;          // 时间步长 (默认30s)
  final Algorithm algorithm; // SHA1/SHA256/SHA512
}
```

---

## 6. 生物识别模块 (Biometric Module)

### 6.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/services/biometric_service.dart` |
| 底层库 | local_auth (^3.0.1) |
| 支持平台 | iOS (Face ID / Touch ID), Android (Fingerprint) |

### 6.2 接口定义

```dart
class BiometricService {
  // 可用性检查
  Future<bool> isDeviceSupported();
  Future<bool> isBiometricEnrolled();
  Future<List<BiometricType>> getAvailableBiometrics();

  // 信息获取
  Future<String> getBiometricTypeName();
  Future<IconData> getBiometricIcon();

  // 认证执行
  Future<bool> authenticate({String reason});

  // 控制
  Future<void> cancelAuthentication();
}
```

---

## 7. 自动锁定模块 (Auto-Lock Module)

### 7.1 模块概述

| 属性 | 值 |
|------|-----|
| 入口文件 | `lib/core/services/auto_lock_service.dart` |
| 核心类 | `AutoLockService`, `AutoLockActivityListener` |
| 状态管理 | ChangeNotifier + Riverpod ChangeNotifierProvider |

### 7.2 接口定义

```dart
class AutoLockService extends ChangeNotifier {
  // 配置
  int get lockDurationMinutes;        // 5/15/30
  set lockDurationMinutes(int minutes);
  bool get isMonitoring;
  int? get remainingSeconds;          // 剩余秒数

  // 生命周期
  void startMonitoring();
  void stopMonitoring();
  void dispose();

  // 活动跟踪
  void recordActivity();
  void pause();
  void resume();

  // 回调
  void addOnLockListener(VoidCallback callback);
  void removeOnLockListener(VoidCallback callback);

  // 快捷操作
  void lockNow();
}

// 全局活动监听 Widget
class AutoLockActivityListener extends ConsumerStatefulWidget {
  final Widget child;
  // 监听全局触摸事件，自动调用 recordActivity()
}
```

### 7.3 Provider 定义

```dart
final autoLockServiceProvider = ChangeNotifierProvider<AutoLockService>(...);
final autoLockDurationProvider = StateProvider<int>((ref) => 5);      // 默认5分钟
final autoLockEnabledProvider = StateProvider<bool>((ref) => true);   // 默认启用
```

---

## 8. 密码工具模块 (Password Tools Module)

### 8.1 密码生成器

**入口文件**: `lib/core/utils/password_generator.dart`

```dart
class PasswordGenerator {
  // 随机密码
  static String generate({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
    String? excludeChars,
  });

  // 易读密码 (排除 0/O/o/1/l/I)
  static String generateReadable({int length = 16});

  // 密码短语 (单词组合)
  static String generatePassphrase({int wordCount = 4});

  // PIN 码
  static String generatePin({int length = 6});

  // 网站定制密码
  static String generateForWebsite({
    required int minLength,
    required int maxLength,
    required bool requireUppercase,
    ...
  });

  // 强度计算
  static int calculateStrength(String password);
  static String getStrengthLabel(int strength);
  static String getStrengthColor(int strength);

  // 验证
  static bool meetsRequirements(String password, {...});
}
```

### 8.2 密码策略

**入口文件**: `lib/core/utils/password_policy.dart`

强度评分规则 (0-100):
- 长度得分: 每字符 +4 分 (上限 40 分)
- 字符种类: 小写/大写/数字/符号 各 +10 分
- 惩罚: 重复字符、连续字符、常见模式扣分

| 分数区间 | 等级 | 颜色 |
|----------|------|------|
| 0-24 | 弱 | 红 |
| 25-49 | 一般 | 橙 |
| 50-74 | 强 | 黄 |
| 75-100 | 很强 | 绿 |

---

## 9. 剪贴板模块 (Clipboard Module)

**入口文件**: `lib/core/services/clipboard_service.dart`

功能:
- 复制密码/用户名到系统剪贴板
- 可配置自动清除时间 (默认 30 秒)
- 显示复制成功通知
