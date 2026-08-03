# Batch 4 — 认证流程页面（Auth Flow）

> 依赖 B1 令牌。认证流程是用户第一印象，`unlock_page` 已有基础动效（AnimatedSwitcher），本 Batch 在此基础上精修。

## B4.1 解锁页品牌化头部

- **目标**：`UnlockPage` 顶部改为品牌区：logo + 渐变背景（`primaryContainer` → surface），欢迎文案与副文案排版对齐设计令牌；生物识别图标与主图标切换保持现有 AnimatedSwitcher 逻辑。
- **涉及文件**：`lib/ui/pages/unlock_page.dart`
- **验收**：浅/深色下品牌区自然过渡，无硬编码色值；窄屏（360dp）不溢出。

## B4.2 解锁错误反馈动效

- **目标**：密码错误时输入框红色边框 + 轻微水平抖动动效，错误卡片保留但样式走令牌；锁定倒计时文案清晰展示剩余时间。
- **涉及文件**：`lib/ui/pages/unlock_page.dart`
- **验收**：连续错误有抖动反馈；锁定状态文案准确；`disableAnimations` 下仍显示错误信息。

## B4.3 设置主密码页视觉统一

- **目标**：`SetupPasswordPage` 与解锁页视觉一致（同一头部品牌区、输入框、按钮）；密码强度指示器整合进表单（复用 B3.3 组件）。
- **涉及文件**：`lib/ui/pages/setup_password_page.dart`
- **验收**：首次进入设置密码的流程视觉连贯；强度指示实时更新。

## B4.4 锁定/解锁过渡动效

- **目标**：锁定按钮与解锁成功跳转使用页面级过渡（`PageRouteBuilder` 淡入缩放或 go_router 过渡），锁定瞬间有明确反馈（如锁屏图标动画）。
- **涉及文件**：`lib/core/routes/app_router.dart`、`lib/ui/pages/vault_page.dart`（锁定按钮）、`unlock_page.dart`
- **验收**：锁定 → 解锁往返动画平滑；`disableAnimations` 下功能完整。

## B4.5 生物识别按钮精修

- **目标**：`UnlockPage` 的生物识别圆形按钮改为「品牌色渐变光环 + 图标」，认证中显示环形进度；与 B4.1 的品牌区协调。
- **涉及文件**：`lib/ui/pages/unlock_page.dart`
- **验收**：指纹/面容图标清晰；认证中状态明确；浅/深色对比度达标。
