# Changelog

所有重要的版本变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

### 新增
- 计划中的功能...

## [2.4.1] - 2025-02-22

### 改进
- 更新项目文档
- 优化版本发布流程

## [2.4.0] - 2025-02-22

### 新增
- **WebDAV 可选加密配置**
  - 支持可选的端到端加密和压缩配置
  - 在 WebDAV 设置页面添加加密和压缩开关
  - 添加加密和压缩配置选项到 SyncConfig 模型

### 改进
- 更新 WebDAV 文档，添加可选加密配置说明

## [2.3.0] - 2025-02-22

### 新增
- **WebDAV 端到端加密**
  - 实现 WebDAV 同步数据端到端加密（AES-256-GCM + GZIP）
  - 更新 WebDAV 页面支持端到端加密传输

### 改进
- 更新 WebDAV 相关文档，添加端到端加密说明

## [2.2.0] - 2025-02-22

### 新增
- **同步模块数据模型**
  - 添加 SyncConfig、SyncState、SyncResult 等同步模型
  - 重构 WebDAV 服务，使用 sync_models 数据模型

### 改进
- **VaultService 增强**
  - 增强搜索功能和标签管理
  - 将 VaultService 改为单例模式
- **UI 更新**
  - 更新 UI 页面适配新的同步模型和服务

### 文档
- 更新 Wiki 文档
  - 架构设计文档
  - 模块设计文档（TOTP、同步模块）
  - API 接口文档
  - 开发计划文档
  - 功能文档和需求文档
  - 认证模块设计文档

## [2.1.2] - 2025-02-22

### 改进
- 更新项目文档
- 优化版本发布流程

## [2.1.1] - 2025-02-21

### 改进
- 优化应用图标配置，使用 flutter_launcher_icons 管理
- 完善 CI/CD 构建流程

### 修复
- 修复 VaultService 单元测试，添加 MockSecureStorage

## [2.1.0] - 2025-02-21

### 改进
- 优化项目文档结构
- 完善版本发布流程

## [2.0.0] - 2025-02-21

### 移除
- **生物识别功能** - 移除指纹和面部识别解锁功能
  - 简化认证流程
  - 减少应用权限需求
  - 仅使用主密码进行身份验证

### 变更
- 认证方式变更为仅支持主密码
- 移除 `local_auth` 依赖

## [1.5.0] - 2025-02-21

### 新增
- **UI 组件库**
  - 基础输入组件（文本输入框、密码输入框）
  - 加载按钮组件
  - 空状态、错误状态组件
  - 确认对话框组件

### 改进
- 优化确认对话框的用户体验
- 完善 UI 组件的可复用性

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

[未发布]: https://github.com/morning-start/vaultly/compare/v2.4.1...HEAD
[2.4.1]: https://github.com/morning-start/vaultly/releases/tag/v2.4.1
[2.4.0]: https://github.com/morning-start/vaultly/releases/tag/v2.4.0
[2.3.0]: https://github.com/morning-start/vaultly/releases/tag/v2.3.0
[2.2.0]: https://github.com/morning-start/vaultly/releases/tag/v2.2.0
[2.1.2]: https://github.com/morning-start/vaultly/releases/tag/v2.1.2
[2.1.1]: https://github.com/morning-start/vaultly/releases/tag/v2.1.1
[2.1.0]: https://github.com/morning-start/vaultly/releases/tag/v2.1.0
[2.0.0]: https://github.com/morning-start/vaultly/releases/tag/v2.0.0
[1.5.0]: https://github.com/morning-start/vaultly/releases/tag/v1.5.0
[1.0.0]: https://github.com/morning-start/vaultly/releases/tag/v1.0.0
[0.1.0]: https://github.com/morning-start/vaultly/releases/tag/v0.1.0
