# P4 界面美观（UI/UX Polish）— 任务总览

> 属于 [`../../phases/README.md`](../../phases/README.md) 的 P4 阶段。
> 设计原则：Material 3、设计令牌统一（禁止散落硬编码色值/圆角/间距）、浅/深色双主题完整、动效克制、保留无障碍语义。

## Batch 划分（按功能相近分组）

| Batch | 主题 | Task 数 | 对应页面/文件 |
|-------|------|---------|---------------|
| B1 | 设计系统与全局组件 | 4 | `ui/theme/`、通用 widgets |
| B2 | 主列表与条目卡片 | 4 | `vault_page`、`entry_card_widget` |
| B3 | 表单与录入 | 5 | `add_entry_page`、密码相关组件 |
| B4 | 认证流程页面 | 5 | `unlock/setup_password/splash` |
| B5 | 详情与设置 | 5 | `entry_detail`、`biometric_settings`、`webdav_*` |

## 通用验收标准（每个 Task 均适用）

1. `flutter analyze` 无新增告警；`flutter test` 通过。
2. 不使用硬编码色值/圆角/间距，统一走设计令牌（`lib/ui/theme/tokens.dart`）。
3. 浅色/深色模式下均清晰可读，无对比度问题。
4. 页面在窄屏（360dp）与长内容下不溢出。
5. 动效时长 ≤300ms 且可无障碍（`disableAnimations` 下可接受）。

## Batch 依赖关系

```
B1（设计令牌）→ B2 / B3 / B4 / B5 均依赖 B1 的 tokens 与组件主题
B2 与 B3/B4/B5 相互独立，可并行
B5 依赖 B3 的 SecureTextField 打磨（字段行复用）
```

## 执行建议

- 每个 Batch 一个 PR，按 B1 → B2 → B3 → B4 → B5 顺序合入；B3/B4 可并行分支。
- 每个 Task 完成后截图对比浅/深色两套主题。
