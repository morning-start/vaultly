# Changelog

所有重要的版本变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

### 新增
- 计划中的功能...

## [1.0.0] - 2025-02-20

### 新增
- **用户认证系统**
  - 主密码设置和验证
  - 生物识别解锁（指纹/面部识别）
  - 自动锁定机制

- **保险库管理**
  - 密码条目增删改查
  - 支持多种条目类型（网站、应用、银行卡、笔记）
  - 自定义字段支持

- **TOTP 双因素认证**
  - 二维码扫描添加 TOTP
  - 手动输入密钥
  - 实时验证码生成

- **密码生成器**
  - 可配置长度和字符集
  - 密码强度评估

- **WebDAV 同步**
  - 多设备数据同步
  - 自动冲突解决
  - 加密传输

- **安全特性**
  - AES-256 加密
  - 本地安全存储
  - 剪贴板自动清理

### 技术实现
- 使用 Flutter 3.38.9 构建
- 跨平台支持（Android、iOS、Windows、macOS、Linux）
- Riverpod 状态管理
- 自动化 CI/CD 流程

## [0.1.0] - 2025-01-15

### 新增
- 项目初始化
- 基础架构搭建
- 核心功能原型

---

## 版本说明

### 版本号格式
版本号格式：`主版本号.次版本号.修订号`

- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 预发布版本标记
- `alpha`：内部测试版本
- `beta`：公开测试版本
- `rc`：候选发布版本

## 如何更新

### Android
1. 下载对应架构的 APK 文件
2. 在设备上点击安装
3. 如提示"未知来源"，请在设置中允许

### 数据备份建议
更新前建议通过 WebDAV 同步或导出备份数据。

---

[未发布]: https://github.com/morning-start/vaultly/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/morning-start/vaultly/releases/tag/v1.0.0
[0.1.0]: https://github.com/morning-start/vaultly/releases/tag/v0.1.0
