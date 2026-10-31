---
project: vaultly
version: 1.0.0
type: architecture-adr
author: TL
date: 2026-10-25
status: accepted
supersedes: architecture.md（路径纠偏项见 §6）
---

# Vaultly 架构决策记录（ADR）与优化方案

> 本文档是「优化代码架构」专项（2026-10-25 启动）的单一事实源。
> 既有文档 architecture.md 保留作历史参考，其中类路径已漂移，以本文为准。

## 0. 背景与摸底结论

Vaultly 为 Flutter 密码管理器（13.5k 行 Dart），Riverpod + GoRouter，feature-first 分层。
整体骨架健康：SessionKeyBridge 依赖倒置（auth 不 import vault）、字段级加密策略、
Provider 派生查询。摸底发现 7 处真实问题，按严重度分级：

### P0 正确性风险

| # | 问题 | 证据 |
|---|------|------|
| A1 | 领域模型全字段可变、无 copyWith/==。内存态 VaultEntry 被各 Provider/UI 共享可变引用，就地改字段不触发 Riverpod 刷新也不落盘 | lib/features/vault/domain/vault_entry.dart |
| A2 | 查询职责已上移 Provider 层，但 VaultService 留有 7 个零调用方方法（searchEntries/getByTag/addTag/removeTag/getAllTags/getEntriesByType/getFavorites）；toggleFavorite 在 Notifier 与 Service 各一份 | lib/features/vault/data/vault_service.dart:212-286 |
| A3 | 存储层单 key 全量 JSON，无写前备份副本（本轮不改，登记为技术债） | vault_service.dart:103-119 |

### P1 可维护性

| # | 问题 | 证据 |
|---|------|------|
| B1 | add_entry_page.dart 929 行巨型表单页，16 个 TextEditing 器堆一个 State | lib/features/vault/presentation/add_entry_page.dart |
| B2 | fromJson 模板在 5 个类重复，base 字段解析改一处要同步 5 处；id/uuid 双命名 | vault_entry.dart |
| B3 | sync `_twoWaySync` 为 TODO 假实现（实际=上传）；syncUpload/upload、syncDownload/download 两对近似方法 | lib/features/sync/domain/sync_orchestrator.dart:189,329 |
| B4 | 裸 catch (e) → e.toString() 直达 UI，AppException 体系未贯穿 | auth_notifier / vault_notifier |

### P2 工程

- C1 测试仅 4 个文件，vault_service/notifier/rollback/加密往返无覆盖
- C2 docs/architecture.md 类路径全部漂移（core/crypto/services/... 已迁至 features/）

## 1. ADR-001：先测试后重构（行为基线）

- **决策**：任何重构前，先为 VaultService（加密存储读写、roundtrip）、VaultNotifier
  （unlock/lock/写操作/失败回滚）、VaultEntry 序列化、字段级加密策略补单测，锁行为基线。
- **备选**：直接重构靠编译期检查 → 放弃，理由：可变引用类问题（A1）编译器发现不了，
  且 QA 验收需要客观依据。
- **后果**：新增 test/vault_*_test.dart，重构每步跑全量测试验证零回归。

## 2. ADR-002：VaultService 瘦身为纯 Repository

- **决策**：删除 7 个零调用方查询方法；toggleFavorite 只保留 Notifier 版本
  （Service 版一并删除，与其它死代码同类）。Service 职责收敛为：
  loadVault / saveVault / addEntry / updateEntry / deleteEntry / replaceAllEntries /
  setEncryptionKey / entries。查询语义全部由 Provider 派生承担（已是现状）。
- **备选**：保留 Service 查询方法做"向后兼容" → 放弃，理由：本应用无外部消费者，
  留着必然继续漂移（正是 A2 的成因）。
- **后果**：vault_service.dart 287 → 约 200 行；调用方仅 vault_notifier.dart 与测试。

## 3. ADR-003：领域模型不可变化

- **决策**：VaultEntry 及 4 个子类改为全 final 字段 + copyWith + ==/hashCode；
  touch() 改为 `VaultEntry withUpdatedTimestamp()` 返回新实例；fromJson 共享基类解析
  （私有 _baseFromJson 消重，B2）；删除 uuid getter，统一用 id（调用点同步替换）。
- **备选**：freezed 代码生成 → 暂不引入，理由：4+1 个类手写可控，避免新增构建依赖与
  生成产物；若后续模型复杂化再引入（触发条件：模型数 >8 或 copyWith 手写出错一次）。
- **后果**：所有"就地改字段"调用点改为 copyWith 重建（本轮逐一排查）；内存态不可变后
  Provider 缓存失效语义更可靠。

## 4. ADR-004：双向同步如实标注

- **决策**：`_twoWaySync` 假实现不删除，但 UI/文案/注释明确标注当前为「上传备份」语义；
  syncUpload/upload、syncDownload/download 合并为单对方法消除重复。
  真双向同步另立需求走 PM。
- **后果**：webdav_sync_page 文案核对修正；orchestrator 公开面缩小。

## 5. ADR-005：add_entry_page 拆分

- **决策**：按条目类型拆 form section 到
  presentation/widgets/entry_forms/（login_form_section.dart 等 4+1 个文件 +
  共享 controller bundle），AddEntryPage 收敛为骨架 + 组装。
- **备选**：整页重写为声明式表单框架 → 过度设计，放弃。
- **后果**：单文件 929 行 → 每片 <250 行。

## 6. 非目标与技术债登记

- A3 存储加固（写前备份/双 key 原子写）→ 登记 docs/06-风险与依赖.md
- B4 异常体系贯穿 → 随改动顺手做，不做专项
- C2 架构文档路径纠偏 → 本轮完成后重写 architecture.md 摘要并互链本文

## 7. Phase 计划与验收门

| Phase | 内容 | 验收 |
|-------|------|------|
| 1 | 行为基线测试 | 新增测试全绿；现有 4 个测试不回归 |
| 2 | Service 死代码清理 | flutter analyze 0 error；基线测试全绿 |
| 3 | 领域模型不可变化 | 基线测试全绿；grep 无 .tags.add( 等就地变更残留 |
| 4 | 表单页拆分 + sync 标注 | analyze 0 error；测试全绿；手动冒烟：添加/编辑 4 类条目 |

回滚方案：单分支顺序提交，每个 Phase 一个 commit，任一 Phase 回归即 revert 到上一 commit。

---

## 8. 后续 ADR 索引

- [ADR-006：多客户端架构与信任边界](./08-多客户端架构与信任边界.md)
  （网页账号记忆 / 自动填充，方案 B 宿主解密；含 R1 校验哈希加固、
  R2 DEK/KEK 密钥层次、R3 同步墓碑、R4 vaultly_core 抽包四项前置重构）
