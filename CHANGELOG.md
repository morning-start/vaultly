# Changelog

所有重要的版本变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [4.0.1] - 2026-10-31

### 修复
- **换新设备后无法解密云端备份**（`Instance of 'InvalidCipherTextException'`）
  - 根因：AES 密钥由 `Argon2id(主密码, 盐)` 派生，而盐值只存在原设备的安全存储里，备份文件一个字节都不带。换设备后重新生成盐，同一个主密码派生出的密钥完全不同，因此必然解密失败——提示却指向「主密码不一致」，误导排查方向
  - 备份改为**自描述信封**（格式 v2）：密钥派生算法、盐值、Argon2 强度与密文写在同一个文件里。盐值不是秘密，它必须随密文一起走
  - 解密时用「主密码 + 文件头参数」重新派生，不再依赖原设备残留数据；本机参数与文件一致时直接复用会话密钥
  - 文件头受 AES-GCM 隐式认证：篡改盐值或强度参数必然解密失败，不会解出错误数据
  - 旧格式备份仍可在原设备解密；在其他设备上解不开时给出可操作提示（在原设备更新后重新上传），不再笼统归因为「密码不对」
- **设置页版本号硬编码为 `2.4.1`**
  - 改为构建时由标签名注入（`--dart-define=APP_VERSION`），与 APK 的 versionName 同源；未注入时显示「开发版」
  - 此前从 2.4.1 一直到 4.0.0，用户看到的版本号都是错的

### 新增
- **云端备份过期提示**：改过主密码后，云端那份备份只有旧密码能解开
  - 上传时记录所用密钥体系的非敏感指纹（口令校验哈希的再哈希，不可逆），与当前指纹比对即可发现失效
  - 同步页显示警示卡并提供「用当前主密码重新上传」一键操作，上传后提示自动消失
  - 采用状态判定而非「改密时弹一次」，因此也覆盖改密时未配置 WebDAV、断网、上传失败等情况

## [未发布]

### 新增
- **回收站与删除同步（墓碑）**：删除的条目不再被立刻抹掉，而是标记后继续参与同步
  - 没有墓碑时，任何一次合并都会让别处删掉的条目复活——这是多设备使用下最容易丢数据的坑
  - 恢复与「彻底删除」都可用；恢复到其他设备同步回去，删除同样同步过去
  - 新增回收站页面（设置 → 回收站），显示删除时间与剩余保留天数；超过 30 天的墓碑自动清除
  - 删除确认文案改为「移入回收站」，不再是「此操作不可恢复」
- **本地数据与云端备份的格式版本闸门**
  - 读取时校验 `schemaVersion`：高于本应用认知的数据一律拒绝读取、拒绝写回，并提示升级
  - 备份负载改为 `v2`（条目含墓碑）。旧版本读不到条目列表会直接报错停手，而不是把删除记录丢掉后再传回去
  - 备份里读不出来的单条数据会计数并告知用户，不再静默跳过

### 变更（不兼容）
- **本地数据格式 v1 → v2、云端备份负载 v1 → v2**
  - 升级不可回退：装过本版本后再降级，低版本读不懂墓碑字段，会把已删除条目当成正常条目
  - 云端备份格式升级后，请**先把所有设备都升级到同一版本再同步**；仍在使用旧版本的设备无法正确处理新备份（这是旧版本自身的限制）
- **合并结果改为确定性**：时间戳相同时不再「保留本地」，而是墓碑优先、再按内容指纹裁决
  - 旧行为下两台设备交替同步会出现条目状态来回抖动

### 修复
- 本地数据版本高于自身时，不再回退到写前备份继续写入（那会把新版本的数据静默替换成旧快照）
- 条目解密失败时不再保留可疑的内存态，避免用不完整内容覆盖磁盘

### 改进
- **核心领域层抽成独立包 `packages/vaultly_core`**（零 Flutter 依赖）
  - 加密原语、条目模型（含墓碑）、字段级加密策略、搜索策略、合并规则、备份负载格式、异常契约迁入
  - App 改为 path 依赖；桌面宿主与 CLI（后续阶段）将共用同一份实现，规则不再允许各端私改
  - CI 新增 core 包独立分析 + 测试 job（纯 Dart SDK，无需 Flutter）
  - **uri 匹配打分推迟到 P7**：App 暂无调用方，提前引入 Public Suffix List 依赖只会腐烂
- **DEK/KEK 两层密钥**：本地数据由随机数据密钥加密，主密码只负责包装它
  - 修改主密码不再重写全部数据（只重新包装），大库改密从「逐条重加密」变成瞬时操作
  - 云备份改用主密码派生的密钥，保证「同一个主密码在任何设备都能解开」
- **存储写入加固**：写前回读校验 + 写前备份（`vault_data.prev`），主数据损坏时自动回退并提示
- **口令校验加固**：废弃 `sha256(password‖salt)`，改为 Argon2id + HKDF 域分离；旧值在解锁后自动迁移并删除
- **CI/CD 缓存优化**
  - `pr-check.yml`：合并 `format-check`/`analyze`/`test` 三个独立 job 为单个 `analyze-and-test`，共享 Runner 和 Flutter 缓存，减少约 1-2 分钟
  - 修正 Android SDK 缓存键：基于工具链版本（Java/Flutter）而非业务代码，业务变更不再导致 SDK 缓存失效
  - 矩阵构建添加 `--no-pub` 参数，避免重复执行 `flutter pub get`
  - `analyze-and-test` 添加 `flutter pub get --offline` 离线回退机制
  - 升级 `codecov-action` 到 v4
- **Android 构建触发方式**
  - 构建工作流改为仅 Tag 推送时触发，不再监听分支推送和 PR
  - 保留 `workflow_dispatch` 手动触发能力

### 修复
- **Android 构建修复**
  - 移除阿里云镜像源（502 Bad Gateway），回退到官方 Google/Maven Central 仓库
  - 依赖 GitHub Actions 缓存保障后续构建速度
- **R8 混淆构建失败修复**
  - 创建 `proguard-rules.pro`，添加 Flutter 引擎、插件、ML Kit、AndroidX、Kotlin 等完整 keep 规则
  - 在 `release` buildType 中添加 `proguardFiles` 配置，防止 R8 误删反射/JNI 调用类

## [3.0.0] - 2026-05-05

### 新增
- **生物识别解锁功能**
  - 恢复指纹和面部识别解锁功能
  - 支持系统级生物识别 API
  - 添加生物识别设置页面

### 改进
- **CI/CD 构建优化**
  - 添加 Concurrency 配置，自动取消同一分支的冗余构建
  - 使用官方 `gradle/actions/setup-gradle@v4` 替代手动缓存，缓存策略更智能
  - 使用矩阵构建合并 APK 和 AAB 构建任务，代码量减少 40%
  - 添加 `flutter pub get --offline` 离线回退机制，缓存命中时跳过网络请求
  - 升级 `actions/cache` 到 v4，提升缓存效率
  - 添加 Gradle Wrapper、Gradle 依赖和 Android SDK 缓存配置
  - 优化 Gradle 构建参数（并行构建、构建缓存、按需配置）
  - 优化 JVM 内存配置，采用 Parallel GC
  - 启用非传递 R 类和非常量 R 类加速构建

- **项目文档**
  - 添加完整的项目文档集
  - 优化文档结构


## [2.5.1] - 2026-05-05

### 改进
- **Android 构建**
  - 添加 Flutter 仓库并改进签名配置
  - 优化 Android 构建流程

## [2.5.0] - 2026-04-30

### 新增
- **生物识别解锁功能**
  - 恢复指纹和面部识别解锁功能
  - 支持系统级生物识别 API

### 改进
- **UI 组件重构**
  - 重构 unlock_page 和 vault_page 使用新组件
  - 重构 add_entry_page 消除重复代码并使用新组件
  - 重构 entry_detail_page 和 webdav_config_page

### 新增（续）
- **EntryTypeHelper 工具类和 EntryCardWidget 组件**
- **密码强度指示器和建议组件**

### 文档
- 更新 CHANGELOG.md 包含 2.2.0 至 2.4.0 版本变更

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

[未发布]: https://github.com/morning-start/vaultly/compare/v4.0.1...HEAD
[4.0.1]: https://github.com/morning-start/vaultly/releases/tag/v4.0.1
[3.0.0]: https://github.com/morning-start/vaultly/releases/tag/v3.0.0
[2.5.1]: https://github.com/morning-start/vaultly/releases/tag/v2.5.1
[2.5.0]: https://github.com/morning-start/vaultly/releases/tag/v2.5.0
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
