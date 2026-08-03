# Vaultly 优化阶段规划（Phases）

> 来源：2026-08 代码审查（安全 5 项 / 性能 3 项 / 代码质量 4 项）
> 原则：每阶段独立可交付、可验证；P1–P3 是风险与体验底线，P4 是视觉打磨，可并行于 P3 之后启动。

## 阶段总览

| Phase | 名称 | 目标 | 状态 |
|-------|------|------|------|
| P1 | 安全加固 Security Hardening | 堵住暴力破解、数据丢失、密钥残留风险 | 待规划 |
| P2 | 性能优化 Performance | 消除 UI 卡顿与无效全量写 | 待规划 |
| P3 | 代码质量清理 Code Cleanup | 删除死代码、统一错误处理、修正同步语义 | 待规划 |
| P4 | 界面美观 UI/UX Polish | 统一设计系统，打磨核心页面视觉与动效 | 已规划 ✅ |

## P1 安全加固（推荐最先做）

**目标**：修复审查中的 🔴 级别安全问题，不改变任何 UI 行为。

- 验证哈希改用 Argon2id 输出派生（替代 SHA-256(password+salt)）
- `loadVault` 区分「无数据」与「解密失败」，失败时抛错而不是静默清空
- 锁定流程同步清除 `VaultService` 的密钥引用
- 主密码哈希使用恒定时间比较
- 移除/禁用 `LocalStorageRepository` 明文 JSON 落盘路径（未接入生产，可整层删除）

**验收**：`flutter analyze` 通过；单元测试覆盖密码验证、损坏数据加载、锁定清密钥；无明文密码写入磁盘的路径。

**依赖**：无。

## P2 性能优化

**目标**：解锁不卡 UI；写盘开销可控。

- Argon2id 密钥派生移入 isolate（`compute`）
- `saveVault` 增加防抖合并，避免连续操作重复全量写
- （可选）本地存储层解析缓存/索引

**验收**：解锁流程 UI 无卡顿（≥30 帧）；连续收藏/删除只触发一次落盘；`flutter analyze` 通过。

**依赖**：P1 完成（改动集中在 crypto / vault_service）。

## P3 代码质量清理

**目标**：消除冗余与误导，统一错误语义。

- 删除 `isar_repository.dart` / `vault_repository.dart` / `local_storage_repository.dart` 死代码与无用 `cryptoServiceProvider`
- 实现 `_twoWaySync` 双向同步，或暂时禁用「双向同步」选项避免误导
- 统一错误处理风格（可恢复返回结果，不可恢复抛异常；去掉泛 catch 吞错）

**验收**：无未使用文件/符号；同步模式行为与 UI 文案一致；`flutter analyze` 通过。

**依赖**：P1 完成（涉及同一批存储层文件）。

## P4 界面美观（UI/UX Polish）✅

**目标**：建立统一设计系统，逐屏打磨核心页面，保持 Material 3 语义与浅/深色一致性。

**范围**：主题与设计令牌 → 全局组件 → 主列表 → 表单录入 → 认证流程 → 详情与设置。

**任务**：详见 [`docs/tasks/ui-aesthetics/`](../tasks/ui-aesthetics/README.md)，共 5 个 Batch、20 个 Task。

**验收（总体）**：所有页面使用设计令牌，无散落硬编码色值/圆角/间距；浅色/深色两套主题视觉完整；关键动效存在且不刺眼；`flutter analyze` 通过。

**依赖**：可与 P3 并行；不建议与 P1/P2 并行改动同一文件（`crypto` 相关无交集，`vault_service` 相关无交集）。

## 执行顺序建议

```
P1 安全加固 → P2 性能优化 → P3 代码清理 ──┐
                                        ├─→ 回归测试 → P4 界面美观
P4（依赖 P3 收尾后可启动，与 P1/P2 无文件交集）──┘
```

## 回归保障

每个 Phase 完成后运行：`flutter analyze` + `flutter test`，并在 Android/iOS 模拟器各过一遍核心流程（设置密码 → 解锁 → 增删改条目 → 搜索 → WebDAV 同步）。
