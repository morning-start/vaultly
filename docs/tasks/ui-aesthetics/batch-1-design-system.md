# Batch 1 — 设计系统与全局组件（Design System & Global Components）

> 本 Batch 是 P4 的地基，其余 Batch 全部依赖其产出的设计令牌与组件主题。

## B1.1 设计令牌 Token 文件

- **目标**：新建 `lib/ui/theme/tokens.dart`，集中定义间距（4/8/12/16/24）、圆角（8/12/16/圆）、阴影层级、动画时长曲线、类型图标配色等常量；`AppTheme` 全部引用令牌，消灭页面内散落硬编码。
- **涉及文件**：`lib/ui/theme/app_theme.dart`（新增 `tokens.dart`）
- **验收**：`tokens.dart` 被主题与至少 2 个页面引用；`grep` 确认 `vault_page`/`entry_card_widget` 中无新增硬编码色值/圆角。

## B1.2 组件主题收口

- **目标**：在 `AppTheme` 中统一配置 Card、Chip、Dialog、SnackBar、NavigationBar、FilledButton/OutlinedButton、InputDecoration 的全局主题；删除页面内重复的局部样式（如 `vault_page` 搜索框的 `filled` 覆盖）。
- **涉及文件**：`lib/ui/theme/app_theme.dart`、`lib/ui/pages/vault_page.dart`
- **验收**：打开 5 个以上页面，按钮/输入框/卡片视觉一致；`flutter analyze` 通过。

## B1.3 通用组件库对齐令牌

- **目标**：`EmptyState`、`ErrorState`、`LoadingButton`、`ConfirmDialog`、`SecureTextField` 统一改用令牌并打磨细节（按压反馈、图标尺寸、danger 按钮语义色）。
- **涉及文件**：`lib/ui/widgets/empty_state.dart`、`error_state.dart`、`loading_button.dart`、`confirm_dialog.dart`、`secure_text_field.dart`
- **验收**：各组件在浅/深色下截图对比正常；`ConfirmDialog` 危险操作按钮为 `colorScheme.error`。

## B1.4 启动页与品牌资产

- **目标**：`SplashPage` 使用品牌 logo（`assets/logo.png`）与品牌色渐变背景，替换纯文字加载；确保 `AppBar` 标题区域在品牌化后不重复。
- **涉及文件**：`lib/ui/pages/splash_page.dart`、`assets/logo.png`
- **验收**：冷启动可见品牌化启动页，过渡到主页面无闪白。
