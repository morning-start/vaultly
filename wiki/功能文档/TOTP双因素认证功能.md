# TOTP 双因素认证功能

> **版本**: v1.0.0  
> **更新日期**: 2026-02-20  
> **作者**: Vaultly Team  
> **文档类型**: 功能文档

---

## 版本历史

| 版本 | 日期 | 修改内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-02-20 | 初始版本 | Vaultly Team |

---

## 一、功能概述

### 1.1 功能描述

TOTP（Time-based One-Time Password）双因素认证功能允许用户为登录条目添加基于时间的一次性密码，实现双因素认证。支持扫描 QR 码快速添加、手动输入密钥、自动刷新验证码等功能。

### 1.2 用户场景

#### 场景 1：为已有账号添加 2FA
> 作为用户，我已为某个网站启用了双因素认证，希望将 TOTP 密钥保存到 Vaultly 中方便使用。

**用户旅程：**
1. 打开目标登录条目的详情页
2. 点击"添加双因素认证"
3. 选择添加方式：扫描 QR 码或手动输入
4. 扫描网站提供的 QR 码
5. 系统自动解析密钥并验证
6. 保存后显示 6 位验证码，30 秒自动刷新

#### 场景 2：查看 TOTP 验证码
> 作为用户，我需要登录某个启用了 2FA 的网站，希望快速获取验证码。

**用户旅程：**
1. 打开 Vaultly 并解锁
2. 找到目标登录条目
3. 在列表或详情页直接查看当前验证码
4. 点击验证码复制到剪贴板
5. 倒计时显示剩余有效时间

#### 场景 3：手动添加 TOTP
> 作为用户，某些网站只提供密钥文本，我需要手动输入。

**用户旅程：**
1. 进入添加 TOTP 界面
2. 选择"手动输入"
3. 输入密钥字符串（Base32 格式）
4. 填写服务商名称和账号
5. 预览验证一次
6. 确认保存

---

## 二、功能需求

### 2.1 功能清单

| 功能 ID | 功能名称 | 优先级 | 描述 |
|---------|---------|--------|------|
| TOTP-001 | 扫码添加 TOTP | P0 | 扫描 QR 码自动解析密钥 |
| TOTP-002 | 手动添加 TOTP | P0 | 手动输入密钥和配置 |
| TOTP-003 | 生成验证码 | P0 | 基于 RFC 6238 生成 6 位验证码 |
| TOTP-004 | 自动刷新 | P0 | 30 秒周期自动更新验证码 |
| TOTP-005 | 倒计时显示 | P0 | 显示验证码剩余有效时间 |
| TOTP-006 | 复制验证码 | P0 | 一键复制验证码到剪贴板 |
| TOTP-007 | 与条目关联 | P0 | TOTP 与登录条目绑定 |
| TOTP-008 | 验证密钥 | P1 | 添加前验证密钥有效性 |
| TOTP-009 | 编辑 TOTP | P1 | 修改 TOTP 配置 |
| TOTP-010 | 删除 TOTP | P1 | 移除双因素认证 |
| TOTP-011 | 批量查看 | P2 | 在列表页显示所有 TOTP |
| TOTP-012 | 导出备份 | P2 | 导出 TOTP 密钥用于备份 |

### 2.2 支持的算法

| 算法 | 支持状态 | 说明 |
|------|---------|------|
| SHA1 | ✅ | RFC 6238 标准，最常用 |
| SHA256 | ✅ | 更安全的选择 |
| SHA512 | ✅ | 最高安全级别 |

### 2.3 参数配置

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| 位数 | 6 | 6-8 | 验证码长度 |
| 时间步长 | 30 秒 | 30-60 | 验证码更新周期 |
| 时间窗口 | ±1 | 0-2 | 容错时间窗口数 |

---

## 三、用户界面

### 3.1 界面清单

| 界面 | 描述 | 关键元素 |
|------|------|---------|
| 添加 TOTP | 选择添加方式 | 扫码按钮、手动输入按钮 |
| QR 扫描 | 扫描 QR 码 | 相机预览、扫描框、手电筒 |
| 手动输入 | 输入密钥 | 密钥输入框、服务商、账号 |
| TOTP 预览 | 验证配置 | 当前验证码、倒计时、确认按钮 |
| 条目详情 | 显示 TOTP | 验证码、复制按钮、倒计时环 |

### 3.2 界面原型

```
┌─────────────────────────────┐
│ ← 添加双因素认证            │
├─────────────────────────────┤
│                             │
│      ┌─────────────┐        │
│      │   📷 扫码   │        │
│      │             │        │
│      │   扫描 QR   │        │
│      └─────────────┘        │
│                             │
│            或               │
│                             │
│      ┌─────────────┐        │
│      │   ⌨️ 手动   │        │
│      │             │        │
│      │  输入密钥   │        │
│      └─────────────┘        │
│                             │
└─────────────────────────────┘
```

```
┌─────────────────────────────┐
│  GitHub  user@example.com   │
├─────────────────────────────┤
│                             │
│  用户名                     │
│  user@example.com      📋   │
│                             │
│  密码                       │
│  ************          📋   │
│                             │
│  ┌─────────────────────┐    │
│  │  🔢 123 456    15s  │    │
│  │      复制验证码     │    │
│  └─────────────────────┘    │
│                             │
│  [编辑]  [删除 TOTP]        │
│                             │
└─────────────────────────────┘
```

---

## 四、验收标准

### 4.1 功能验收

| 验收项 | 验收标准 | 测试方法 |
|--------|---------|---------|
| QR 码扫描 | 正确解析标准 otpauth URI | 集成测试 |
| 手动输入 | 接受 Base32 格式密钥 | 单元测试 |
| 验证码生成 | 与 Google Authenticator 结果一致 | 对比测试 |
| 自动刷新 | 30 秒周期准确更新 | 手动测试 |
| 复制功能 | 验证码正确复制到剪贴板 | 端到端测试 |
| 条目关联 | TOTP 正确关联到登录条目 | 单元测试 |

### 4.2 性能验收

| 指标 | 目标值 | 测量方法 |
|------|--------|---------|
| 验证码生成 | < 10ms | 性能测试 |
| QR 码解析 | < 100ms | 性能测试 |
| 界面刷新 | < 16ms (60fps) | 性能测试 |

### 4.3 安全验收

| 验收项 | 验收标准 |
|--------|---------|
| 密钥存储 | TOTP 密钥加密存储 |
| 内存安全 | 密钥不长期驻留内存 |
| 剪贴板安全 | 验证码 30 秒后自动清除 |

---

## 五、代码实现映射

### 5.1 核心实现文件

| 功能 | 实现文件 | 关键类/方法 |
|------|----------|-------------|
| **TOTP 服务** | `lib/core/services/totp_service.dart` | `TOTPService` |
| **TOTP 配置** | `lib/core/services/totp_service.dart` | `TOTPConfig` |
| **QR 扫描** | `lib/ui/pages/qr_scanner_page.dart` | `QRScannerPage` |
| **TOTP 显示** | `lib/ui/widgets/totp_display.dart` | `TOTPDisplayWidget` |

### 5.2 TOTP 服务实现

```dart
// lib/core/services/totp_service.dart
class TOTPService {
  static const int _defaultDigits = 6;
  static const int _defaultPeriod = 30;

  // 生成 TOTP 验证码
  String generateTOTP(String secret, {
    int digits = _defaultDigits,
    int period = _defaultPeriod,
  }) {
    final counter = _getTimeCounter(period);
    return _generateHOTP(secret, counter, digits);
  }

  // 验证 TOTP 验证码
  bool validateTOTP(String code, String secret, {
    int window = 1,
    int digits = _defaultDigits,
    int period = _defaultPeriod,
  }) {
    if (code.length != digits) return false;
    
    final counter = _getTimeCounter(period);
    
    // 检查时间窗口内的所有可能
    for (int i = -window; i <= window; i++) {
      final expectedCode = _generateHOTP(secret, counter + i, digits);
      if (expectedCode == code) {
        return true;
      }
    }
    
    return false;
  }

  // 解析 otpauth:// URI
  TOTPConfig? parseOTPAuthURI(String uri) {
    try {
      if (!uri.startsWith('otpauth://totp/')) {
        return null;
      }

      final parsedUri = Uri.parse(uri);
      final path = parsedUri.path;
      final query = parsedUri.queryParameters;

      String? secret = query['secret'];
      if (secret == null || secret.isEmpty) return null;

      String issuer = query['issuer'] ?? '';
      String accountName = path.substring(1);

      if (issuer.isEmpty && accountName.contains(':')) {
        final parts = accountName.split(':');
        issuer = parts[0];
        accountName = parts[1];
      }

      final digits = int.tryParse(query['digits'] ?? '') ?? _defaultDigits;
      final period = int.tryParse(query['period'] ?? '') ?? _defaultPeriod;
      final algorithm = _parseAlgorithm(query['algorithm']);

      return TOTPConfig(
        secret: secret.toUpperCase(),
        issuer: issuer,
        accountName: accountName,
        digits: digits,
        period: period,
        algorithm: algorithm,
      );
    } catch (_) {
      return null;
    }
  }

  // 获取剩余秒数
  int getRemainingSeconds({int period = _defaultPeriod}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return period - (now % period);
  }

  // HOTP 生成（TOTP 基础）
  String _generateHOTP(String secret, int counter, int digits) {
    final key = _base32Decode(secret);
    final counterBytes = _intToBytes(counter);
    
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(counterBytes);
    final hash = digest.bytes;
    
    // 动态截断
    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);
    
    final otp = binary % _pow10(digits);
    return otp.toString().padLeft(digits, '0');
  }

  // Base32 解码
  Uint8List _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleanInput = input.toUpperCase()
        .replaceAll('=', '')
        .replaceAll(' ', '');
    
    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    
    for (int i = 0; i < cleanInput.length; i++) {
      final char = cleanInput[i];
      final value = alphabet.indexOf(char);
      if (value < 0) continue;
      
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      
      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xFF);
        bitsLeft -= 8;
      }
    }
    
    return Uint8List.fromList(output);
  }
}

// TOTP 配置
class TOTPConfig {
  final String secret;
  final String issuer;
  final String accountName;
  final int digits;
  final int period;
  final Algorithm algorithm;

  TOTPConfig({
    required this.secret,
    required this.issuer,
    required this.accountName,
    this.digits = 6,
    this.period = 30,
    this.algorithm = Algorithm.sha1,
  });
}

enum Algorithm { sha1, sha256, sha512 }
```

---

## 六、相关文档

### 6.1 渐进式文档链
- [TOTP 双因素认证需求](../需求文档/TOTP双因素认证需求.md) - 数据模型、数据流动、状态管理
- [TOTP 双因素认证架构](../架构文档/TOTP双因素认证架构.md) - 技术选型、实现方案

### 6.2 模块设计
- [TOTP 模块](../03-模块设计/TOTP模块.md) - 详细模块设计

### 6.3 数据模型
- [数据字典](../04-数据模型/数据字典.md) - 核心数据结构

---

## 七、变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-02-20 | 初始版本 | Vaultly Team |
