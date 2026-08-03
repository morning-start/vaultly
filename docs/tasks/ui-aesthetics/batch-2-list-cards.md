# Batch 2 — 主列表与条目卡片（Vault List & Entry Cards）

> 依赖 B1 的设计令牌。本 Batch 只改列表层视觉，不改数据逻辑。

## B2.1 条目卡片重设计

- **目标**：`EntryCardWidget` 升级：类型图标改为带语义色的圆角徽章而非 `CircleAvatar`，收藏星标常驻（未收藏用浅色描边），增加按压高亮与滑动/长按预留位，subtitle 显示类型名 + 更新时间。
- **涉及文件**：`lib/ui/widgets/entry_card_widget.dart`、`lib/ui/widgets/entry_type_helper.dart`（如需补充颜色映射）
- **验收**：卡片在浅/深色下对比度达标；星标切换有状态变化；长标题不溢出。

## B2.2 搜索与筛选区整合

- **目标**：`vault_page` 顶部的搜索框 + 横向 FilterChip 改为紧凑一致的设计：搜索框收进「搜索 + 类型筛选」组合区，筛选 chip 选中态用 `secondaryContainer`，整体对齐令牌间距。
- **涉及文件**：`lib/ui/pages/vault_page.dart`
- **验收**：窄屏不溢出；搜索时筛选 chip 不跳动；清除搜索有动画过渡。

## B2.3 列表三态（加载/空/错误）统一

- **目标**：列表页的 loading / empty / error 三态统一走通用组件与设计令牌；空态按「无条目 / 搜索无结果 / 收藏为空」区分文案与操作按钮。
- **涉及文件**：`lib/ui/pages/vault_page.dart`、`lib/ui/widgets/empty_state.dart`、`error_state.dart`
- **验收**：三种状态分别触发验证；文案与图标语义正确。

## B2.4 列表动效与滚动体验

- **目标**：列表项使用 `AnimatedList`/隐式动画做增删过渡（新条目插入、删除时淡出+滑出）；FAB 与列表滚动联动（下滚隐藏、上滚显示）。
- **涉及文件**：`lib/ui/pages/vault_page.dart`
- **验收**：增删条目有平滑过渡；滚动时 FAB 行为合理；`disableAnimations` 下功能完整。
