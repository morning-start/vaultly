# Batch 5 — 详情与设置页面（Detail & Settings）

> 依赖 B1 令牌与 B3 的 SecureTextField 打磨。本 Batch 覆盖条目详情、生物识别设置与 WebDAV 同步页。

## B5.1 条目详情页字段展示

- **目标**：`EntryDetailPage` 字段区改为分组卡片：每行「字段名 + 值 + 复制按钮」，敏感字段（密码/CVV/证件号）默认打码，点按眼睛图标揭示（现有 `_showSensitive` 逻辑保留）；标题区展示类型徽章与收藏切换。
- **涉及文件**：`lib/ui/pages/entry_detail_page.dart`
- **验收**：敏感字段默认遮罩；复制有 SnackBar 反馈（复用 `ClipboardService`）；字段行在浅/深色下可读。

## B5.2 TOTP 展示组件

- **目标**：登录条目详情中的 TOTP 码用「大号等宽数字 + 30s 倒计时环形进度」呈现，倒计时临近刷新时颜色过渡；自动复制按钮沿用剪贴板服务。
- **涉及文件**：`lib/ui/pages/entry_detail_page.dart`、`lib/ui/widgets/`（可新增 `totp_display` 组件）
- **验收**：倒计时与 `TOTPService.getRemainingSeconds()` 一致；刷新时无跳动错位。

## B5.3 生物识别设置页打磨

- **目标**：`BiometricSettingsPage` 使用 `SwitchListTile` + 说明卡片，展示设备支持状态、已注册指纹/面容提示；危险操作（禁用）用确认对话框。
- **涉及文件**：`lib/ui/pages/biometric_settings_page.dart`
- **验收**：开关状态与 `authState` 一致；禁用流程有确认步骤。

## B5.4 WebDAV 配置/同步页打磨

- **目标**：`WebDAVConfigPage` 表单（服务器地址/账号/密码）分区化，密码字段用 `SecureTextField`；`WebDAVSyncPage` 的同步状态（成功/失败/进行中）用状态卡片 + 进度条呈现，同步历史列表对齐令牌。
- **涉及文件**：`lib/ui/pages/webdav_config_page.dart`、`lib/ui/pages/webdav_sync_page.dart`
- **验收**：配置表单在浅/深色下可读；同步中/成功/失败三态视觉区分明确。

## B5.5 全局反馈与空态补全

- **目标**：全 App 的 SnackBar 统一样式（成功/错误语义色）、加载遮罩统一；`webdav_sync_page` 空态复用 `EmptyState.sync`；检查其余页面散落的 `showDialog`/`SnackBar` 是否符合令牌。
- **涉及文件**：`lib/ui/theme/app_theme.dart`（SnackBar 主题）、各页面
- **验收**：全局 SnackBar 样式一致；无页面直接 `Colors.red` 之类硬编码反馈色。
