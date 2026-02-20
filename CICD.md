# Vaultly CI/CD 流程文档

本文档详细说明 Vaultly 项目的持续集成和持续部署（CI/CD）流程。

## 目录

- [概述](#概述)
- [工作流文件](#工作流文件)
- [触发条件](#触发条件)
- [构建流程](#构建流程)
- [发布流程](#发布流程)
- [环境配置](#环境配置)
- [使用方法](#使用方法)
- [故障排查](#故障排查)

## 概述

Vaultly 使用 GitHub Actions 作为 CI/CD 平台，实现了以下自动化流程：

- **代码质量检查**：自动格式化检查、静态分析、单元测试
- **多架构 Android 构建**：支持 ARM64、ARMv7、x86_64 架构
- **自动发布**：推送到 GitHub Releases

## 工作流文件

### 1. Build Android (`build-android.yml`)

**路径**: `.github/workflows/build-android.yml`

**功能**:
- 代码分析和测试
- 多架构 APK 构建（arm64、arm、x86_64）
- Android App Bundle (AAB) 构建
- 自动发布到 GitHub Releases

**任务流程**:

```
┌─────────────────┐
│ analyze-and-test│
│ 代码分析和测试   │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│build-   │ │build-   │
│android- │ │android- │
│apk      │ │aab      │
│APK构建  │ │AAB构建  │
└────┬────┘ └────┬────┘
     │           │
     └─────┬─────┘
           ▼
    ┌─────────────┐
    │   release   │
    │ GitHub发布  │
    └─────────────┘
```

### 2. PR Check (`pr-check.yml`)

**路径**: `.github/workflows/pr-check.yml`

**功能**:
- 代码格式检查
- 静态代码分析
- 单元测试
- Android Debug 构建测试

**任务流程**:

```
┌─────────────┐  ┌─────────┐  ┌──────┐  ┌──────────────┐
│format-check │  │ analyze │  │ test │  │build-android-│
│ 格式检查    │  │ 代码分析│  │ 测试 │  │  test        │
└──────┬──────┘  └────┬────┘  └──┬───┘  └──────┬───────┘
       │              │          │             │
       └──────────────┴────┬─────┴─────────────┘
                           ▼
                    ┌─────────────┐
                    │pr-check-    │
                    │summary      │
                    │PR检查汇总   │
                    └─────────────┘
```

## 触发条件

### Build Android 工作流

| 触发方式 | 条件 | 执行内容 |
|---------|------|---------|
| **Push 标签** | `v*` (如 `v1.0.0`) | 完整构建 + 发布到 Releases |
| **Push 分支** | `main`, `dev` | 仅代码分析和测试 |
| **Pull Request** | 目标分支为 `main` 或 `dev` | 仅代码分析和测试 |
| **手动触发** | workflow_dispatch | 完整构建（不发布） |

### PR Check 工作流

| 触发方式 | 条件 | 执行内容 |
|---------|------|---------|
| **Pull Request** | 目标分支为 `main` 或 `dev` | 完整 PR 检查 |

## 构建流程

### 阶段 1: 代码分析和测试

```yaml
Job: analyze-and-test
```

**执行步骤**:
1. 检出代码 (`actions/checkout@v4`)
2. 设置 Flutter 环境 (`subosito/flutter-action@v2`)
3. 获取项目依赖 (`flutter pub get`)
4. 运行代码分析 (`flutter analyze`)
5. 运行单元测试 (`flutter test`)

### 阶段 2: Android APK 构建

```yaml
Job: build-android-apk
依赖: analyze-and-test
```

**执行步骤**:
1. 检出代码
2. 设置 Java 17 环境 (`actions/setup-java@v4`)
3. 设置 Flutter 环境
4. 获取项目依赖
5. 构建多架构 APK:
   ```bash
   flutter build apk \
     --release \
     --split-per-abi \
     --build-name=${{ github.ref_name }} \
     --build-number=${{ github.run_number }}
   ```
6. 重命名 APK 文件:
   - `app-arm64-v8a-release.apk` → `vaultly-{版本}-android-arm64.apk`
   - `app-armeabi-v7a-release.apk` → `vaultly-{版本}-android-arm.apk`
   - `app-x86_64-release.apk` → `vaultly-{版本}-android-x86_64.apk`
7. 上传构建产物

### 阶段 3: Android AAB 构建

```yaml
Job: build-android-aab
依赖: analyze-and-test
```

**执行步骤**:
1. 检出代码
2. 设置 Java 17 环境
3. 设置 Flutter 环境
4. 获取项目依赖
5. 构建 AAB:
   ```bash
   flutter build appbundle \
     --release \
     --build-name=${{ github.ref_name }} \
     --build-number=${{ github.run_number }}
   ```
6. 重命名 AAB 文件:
   - `app-release.aab` → `vaultly-{版本}-android.aab`
7. 上传构建产物

### 阶段 4: GitHub Releases 发布

```yaml
Job: release
依赖: build-android-apk, build-android-aab
触发条件: 推送标签 v*
```

**执行步骤**:
1. 检出代码
2. 下载所有构建产物
3. 整理产物文件
4. 创建 GitHub Release:
   - 自动检测预发布版本（标签包含 `alpha`、`beta`、`rc`）
   - 自动生成发布说明
   - 上传所有 APK 和 AAB 文件

## 发布流程

### 自动发布

当推送标签时，自动触发发布流程：

```bash
# 创建标签
git tag -a v1.0.0 -m "Release v1.0.0"

# 推送标签到远程仓库
git push origin v1.0.0
```

**发布产物**:

| 文件名 | 说明 | 适用设备 |
|-------|------|---------|
| `vaultly-{版本}-android-arm64.apk` | ARM64 架构 APK | 现代 Android 设备（推荐） |
| `vaultly-{版本}-android-arm.apk` | ARMv7 架构 APK | 旧 Android 设备 |
| `vaultly-{版本}-android-x86_64.apk` | x86_64 架构 APK | Android 模拟器 |
| `vaultly-{版本}-android.aab` | App Bundle | Google Play 商店 |

### 版本号规则

- **正式版本**: `v1.0.0`, `v1.1.0`
- **预发布版本**: `v1.0.0-beta.1`, `v1.0.0-rc.1`, `v1.0.0-alpha.1`

预发布版本会自动标记为 "Pre-release"。

## 环境配置

### 环境变量

```yaml
env:
  FLUTTER_VERSION: '3.38.9'  # Flutter SDK 版本
  JAVA_VERSION: '17'          # Java SDK 版本
```

### 运行环境

- **操作系统**: Ubuntu Latest
- **Flutter 渠道**: Stable
- **Java 发行版**: Temurin

### GitHub Secrets 配置

为了自动签名 Android 应用，需要在 GitHub 仓库中配置以下 Secrets：

| Secret 名称 | 说明 | 获取方式 |
|------------|------|---------|
| `KEYSTORE_B64` | 密钥库文件的 Base64 编码 | 见下方转换步骤 |
| `STORE_PASSWORD` | 密钥库密码 | 创建密钥库时设置的密码 |
| `KEY_PASSWORD` | 密钥密码 | 创建密钥时设置的密码 |
| `KEY_ALIAS` | 密钥别名 | 如 `morningstart-vaultly` |

#### 生成 Base64 编码的密钥库

在 PowerShell 中执行：

```powershell
# 将 .jks 文件转换为 Base64
[Convert]::ToBase64String([IO.File]::ReadAllBytes("my-release-key.jks")) | Set-Clipboard
```

或者在 Linux/macOS：

```bash
base64 -i my-release-key.jks
```

#### 配置 Secrets 步骤

1. 进入 GitHub 仓库页面
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 添加以下 4 个 Secrets：
   - `KEYSTORE_B64`: Base64 编码的密钥库内容
   - `STORE_PASSWORD`: 密钥库密码
   - `KEY_PASSWORD`: 密钥密码
   - `KEY_ALIAS`: 密钥别名（如 `morningstart-vaultly`）

### 依赖的操作

| 操作 | 版本 | 用途 |
|-----|------|------|
| `actions/checkout` | v4 | 检出代码 |
| `actions/setup-java` | v4 | 设置 Java 环境 |
| `subosito/flutter-action` | v2 | 设置 Flutter 环境 |
| `actions/upload-artifact` | v4 | 上传构建产物 |
| `actions/download-artifact` | v4 | 下载构建产物 |
| `softprops/action-gh-release` | v1 | 创建 GitHub Release |
| `codecov/codecov-action` | v3 | 上传测试覆盖率 |

## 使用方法

### 本地开发

**1. 代码格式化**
```bash
flutter format .
```

**2. 代码分析**
```bash
flutter analyze
```

**3. 运行测试**
```bash
flutter test
```

**4. 本地构建 APK**
```bash
flutter build apk --release --split-per-abi
```

**5. 本地构建 AAB**
```bash
flutter build appbundle --release
```

### 发布新版本

**方式 1: 命令行发布**
```bash
# 1. 确保代码已提交
git add .
git commit -m "Prepare release v1.0.0"

# 2. 创建标签
git tag -a v1.0.0 -m "Release v1.0.0"

# 3. 推送标签
git push origin v1.0.0
```

**方式 2: GitHub Web 界面发布**
1. 进入 GitHub 仓库页面
2. 点击 "Actions" 标签
3. 选择 "Build Android" 工作流
4. 点击 "Run workflow"
5. 选择分支，点击 "Run workflow"

### 查看构建状态

1. 进入 GitHub 仓库页面
2. 点击 "Actions" 标签
3. 查看工作流运行记录
4. 点击具体运行记录查看详细日志

## 故障排查

### 常见问题

#### 1. 构建失败：依赖获取失败

**症状**: `flutter pub get` 步骤失败

**解决方案**:
```bash
# 本地清理依赖
flutter clean
flutter pub get
```

#### 2. 构建失败：代码分析错误

**症状**: `flutter analyze` 报告错误

**解决方案**:
```bash
# 本地修复
flutter analyze
# 根据提示修复代码问题
```

#### 3. 构建失败：测试未通过

**症状**: `flutter test` 失败

**解决方案**:
```bash
# 本地运行测试
flutter test
# 修复失败的测试
```

#### 4. 发布失败：权限不足

**症状**: 创建 Release 时 403 错误

**解决方案**:
- 确保 `GITHUB_TOKEN` 有 `contents: write` 权限
- 检查仓库设置中的 Actions 权限

#### 5. APK 安装失败

**症状**: 设备上安装 APK 失败

**原因和解决方案**:
- **架构不匹配**: 下载与设备架构匹配的 APK
- **签名冲突**: 卸载旧版本后重新安装
- **未知来源**: 在设置中允许安装未知来源应用

### 调试构建

**1. 查看详细日志**
在 GitHub Actions 页面点击失败的作业，查看详细日志。

**2. 本地复现**
```bash
# 使用与 CI 相同的 Flutter 版本
flutter --version

# 清理并重新构建
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --verbose
```

**3. 手动触发工作流**
在 GitHub Actions 页面手动触发工作流进行调试。

## 最佳实践

### 开发流程

1. **功能开发**: 在功能分支上开发
2. **本地检查**: 运行 `flutter analyze` 和 `flutter test`
3. **提交 PR**: 提交到 `dev` 分支
4. **PR 检查**: 等待 CI 检查通过
5. **合并代码**: 合并到 `dev` 分支
6. **发布测试**: 从 `dev` 创建预发布标签
7. **正式发布**: 合并到 `main`，创建正式标签

### 版本管理

- 使用语义化版本号: `v主版本.次版本.修订号`
- 预发布版本使用: `-alpha`、`-beta`、`-rc` 后缀
- 每个发布都应该有对应的 Git 标签

### 安全建议

- 不要将敏感信息硬编码在代码中
- 使用 GitHub Secrets 管理密钥
- 定期更新依赖包
- 启用分支保护规则

## 附录

### 相关链接

- [GitHub Actions 文档](https://docs.github.com/cn/actions)
- [Flutter 构建和发布文档](https://docs.flutter.dev/deployment/cd)
- [Android 应用签名指南](https://developer.android.com/studio/publish/app-signing)

### 配置文件

- **工作流配置**: `.github/workflows/`
- **Flutter 配置**: `pubspec.yaml`
- **Android 配置**: `android/app/build.gradle.kts`

---

*文档版本: 1.0*  
*最后更新: 2025-02-20*
