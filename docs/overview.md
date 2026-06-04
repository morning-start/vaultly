---
project: vaultly
version: 2.4.1
type: overview
author: auto-generated
date: 2026-06-04
status: stable
tags: [flutter, password-manager, security, cross-platform]
---

# Vaultly - 项目概览

## 1. 项目简介

**Vaultly** 是一款跨平台密码与敏感信息管理器，基于 Flutter 框架构建，支持 Android 和 iOS 平台。项目采用端到端加密架构，确保用户数据在本地和传输过程中的安全性。

| 属性 | 值 |
|------|-----|
| 项目名称 | Vaultly |
| 当前版本 | 2.4.1 (Build 1) |
| 开发语言 | Dart (SDK ^3.10.8) |
| UI 框架 | Flutter |
| 目标平台 | Android / iOS |
| 许可证 | Private |

## 2. 核心功能

### 2.1 安全认证
- **主密码保护**: 使用 Argon2id 算法进行密钥派生，抵抗暴力破解
- **生物识别解锁**: 支持 Face ID (iOS)、指纹识别 (Android/iOS)
- **自动锁定**: 可配置 5/15/30 分钟无操作后自动锁定
- **防暴力破解**: 5 次失败短锁 5 分钟，10 次失败长锁 30 分钟

### 2.2 保险库管理
- **多类型条目支持**:
  - 登录凭证 (用户名/密码/邮箱/URL/TOTP)
  - 银行卡 (卡号/持卡人/CVV/有效期)
  - 安全笔记 (支持 Markdown)
  - 身份信息 (姓名/证件号/地址/联系方式)
  - 自定义条目 (完全自定义字段)
- **文件夹分类**: 支持层级文件夹组织
- **标签系统**: 多标签分类与筛选
- **收藏功能**: 快速访问常用条目
- **全局搜索**: 支持标题、用户名、邮箱等多字段搜索

### 2.3 密码工具
- **密码生成器**: 随机密码 / 易读密码 / 密码短语 / PIN 码
- **密码强度检测**: 实时评估密码安全等级
- **TOTP 验证码**: 内置双因素认证验证码生成器 (RFC 6238)
- **QR 码扫描**: 快速导入 OTP Auth URI 配置

### 2.4 数据同步
- **WebDAV 同步**: 支持标准 WebDAV 协议的云存储同步
- **加密传输**: AES-256-GCM 加密 + GZIP 压缩
- **多种模式**: 仅上传(备份) / 仅下载(恢复) / 双向同步 / 手动同步
- **冲突处理**: 本地优先 / 远程优先 / 合并 / 跳过

## 3. 技术栈

```
┌─────────────────────────────────────────────────────┐
│                     应用层                          │
│  Flutter UI │ Riverpod 状态管理 │ GoRouter 路由     │
├─────────────────────────────────────────────────────┤
│                     业务层                          │
│  AuthService │ VaultService │ WebDAVService        │
│  TOTPService │ BiometricService │ AutoLockService   │
├─────────────────────────────────────────────────────┤
│                     基础设施层                       │
│  CryptoService(AES-256-GCM+Argon2id)               │
│  FlutterSecureStorage │ path_provider              │
├─────────────────────────────────────────────────────┤
│                   第三方依赖                        │
│  encrypt │ pointycastle │ crypto │ local_auth      │
│  webdav_client │ otp │ mobile_scanner │ uuid      │
│  url_launcher │ intl │ shared_preferences          │
└─────────────────────────────────────────────────────┘
```

### 3.1 核心依赖清单

| 包名 | 版本 | 用途 |
|------|------|------|
| flutter_riverpod | ^2.6.1 | 响应式状态管理 |
| go_router | ^14.0.0 | 声明式路由 |
| encrypt | ^5.0.3 | AES-256-GCM 加密 |
| pointycastle | ^3.9.1 | Argon2id 密钥派生 |
| crypto | ^3.0.6 | SHA-256 哈希 |
| flutter_secure_storage | ^10.0.0 | 安全本地存储 |
| local_auth | ^3.0.1 | 生物识别认证 |
| webdav_client | ^1.2.2 | WebDAV 客户端 |
| otp | ^3.2.0 | TOTP 支持 |
| mobile_scanner | ^7.2.0 | QR 码扫描 |

## 4. 项目结构

```
lib/
├── main.dart                          # 应用入口
├── core/
│   ├── crypto/services/
│   │   ├── auth_service.dart           # 认证服务（密码/生物识别）
│   │   └── crypto_service.dart         # 加密服务（AES/Argon2id）
│   ├── models/
│   │   ├── vault_entry.dart            # 条目数据模型（5种类型）
│   │   ├── folder.dart                 # 文件夹模型
│   │   ├── sync_models.dart            # 同步数据模型
│   │   └── sync_metadata.dart          # 同步元数据
│   ├── providers/
│   │   ├── auth_provider.dart          # 认证状态管理
│   │   ├── vault_service_provider.dart # 保险库服务提供者
│   │   └── webdav_provider.dart        # WebDAV 状态提供者
│   ├── repositories/
│   │   ├── isar_repository.dart        # Isar 数据库仓库
│   │   ├── local_storage_repository.dart # 本地存储仓库
│   │   └── vault_repository.dart       # 保险库数据仓库
│   ├── routes/
│   │   └── app_router.dart             # 路由配置（10个页面）
│   ├── services/
│   │   ├── vault_service.dart          # 保险库核心服务
│   │   ├── webdav_service.dart         # WebDAV 同步服务
│   │   ├── totp_service.dart           # TOTP 服务
│   │   ├── biometric_service.dart      # 生物识别服务
│   │   ├── auto_lock_service.dart      # 自动锁定服务
│   │   └── clipboard_service.dart      # 剪贴板服务
│   └── utils/
│       ├── password_generator.dart     # 密码生成器
│       └── password_policy.dart        # 密码策略
├── ui/
│   ├── pages/                          # 页面（10个）
│   │   ├── splash_page.dart
│   │   ├── setup_password_page.dart
│   │   ├── unlock_page.dart
│   │   ├── vault_page.dart
│   │   ├── add_entry_page.dart
│   │   ├── entry_detail_page.dart
│   │   ├── webdav_config_page.dart
│   │   ├── webdav_sync_page.dart
│   │   ├── biometric_settings_page.dart
│   │   └── qr_scanner_page.dart
│   ├── theme/
│   │   └── app_theme.dart             # 主题配置
│   └── widgets/                        # 通用组件（12个）
│       ├── custom_text_field.dart
│       ├── secure_text_field.dart
│       ├── entry_card_widget.dart
│       ├── password_generator_dialog.dart
│       ├── password_strength_indicator.dart
│       └── ...
└── assets/
    └── logo.png                        # 应用图标
```

## 5. 页面路由

| 路由路径 | 页面 | 说明 |
|----------|------|------|
| `/` | SplashPage | 启动页（加载检测） |
| `/setup` | SetupPasswordPage | 首次设置主密码 |
| `/unlock` | UnlockPage | 密码/生物识别解锁 |
| `/vault` | VaultPage | 保险库主页 |
| `/add` | AddEntryPage | 添加新条目 |
| `/entry/:id` | EntryDetailPage | 条目详情 |
| `/entry/:id/edit` | AddEntryPage | 编辑条目 |
| `/webdav` | WebDAVSyncPage | 同步管理 |
| `/webdav/config` | WebDAVConfigPage | WebDAV 配置 |
| `/settings/biometric` | BiometricSettingsPage | 生物识别设置 |

## 6. 国际化

| 语言 | Locale | 状态 |
|------|--------|------|
| 简体中文 | zh_CN | 主要语言 |
| 英语 | en_US | 支持 |

## 7. 构建与运行

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建发布版本
flutter build apk --release          # Android
flutter build ios --release          # iOS

# 生成应用图标
flutter pub run flutter_launcher_icons
```
