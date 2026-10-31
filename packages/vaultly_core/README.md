# vaultly_core

Vaultly 的核心领域层（ADR-006 R4）：**零 Flutter 依赖**的纯 Dart 包。

放这里的只有「正确性」——任何一方私改都会造成多端行为分叉的规则：

| 模块 | 内容 |
|---|---|
| `crypto` | AES-256-GCM、Argon2id、HKDF（域分离）、DEK/KEK 包装、备份信封 |
| `vault` | 条目模型（含墓碑 `deletedAt`）、条目 JSON 编解码、字段级加密策略、搜索策略 |
| `sync` | 合并（确定性 LWW + C5）、备份负载 v2 与版本闸门 |
| `exceptions` | 跨层异常契约 |

明确**不**放这里：存储（flutter_secure_storage）、Provider/Notifier（flutter_riverpod）、
UI、网络客户端。这些是平台适配层，留在 App 里。

## 约束

- `dart analyze` 与 `dart test` 必须在纯 Dart VM 下通过（CI 有独立 job）
- 不得引入 `package:flutter/*` 或任何 Flutter 插件
- 公开 API 走 [lib/vaultly_core.dart](lib/vaultly_core.dart) barrel；`src/` 内部用相对导入

## 运行

```bash
cd packages/vaultly_core
dart pub get
dart test
```

## 待办（登记未做）

- **uri 匹配打分**（eTLD+1 规范化需要 Public Suffix List）推迟到 P7，
  届时连同 fixture 语料一起进这个包——现在 App 还没有任何调用方，
  提前引入 `publicsuffix` 依赖只会在没有用例的情况下腐烂。
