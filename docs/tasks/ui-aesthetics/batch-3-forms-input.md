# Batch 3 — 表单与录入（Forms & Entry）

> 依赖 B1 令牌；`add_entry_page.dart` 约 32KB、线性堆叠大量字段，本 Batch 同时做结构拆分与视觉升级。

## B3.1 录入表单分区化

- **目标**：将 `AddEntryPage` 按条目类型拆分为分区表单（SectionCard：基本信息 / 凭证 / 备注），类型间切换保留已填内容；长表单可滚动，保存按钮固定底部安全区。
- **涉及文件**：`lib/ui/pages/add_entry_page.dart`（可拆出 `widgets/entry_form/` 子组件）
- **验收**：登录/银行卡/笔记/身份四类表单分区清晰；切换类型不丢已填数据；保存按钮不被键盘遮挡。

## B3.2 SecureTextField 与密码可见性

- **目标**：`SecureTextField` 打磨：密码可见性切换图标带按压反馈、`AnimatedSwitcher` 过渡；「生成密码」快捷入口；自动填充建议与 `autofillHints` 对齐。
- **涉及文件**：`lib/ui/widgets/secure_text_field.dart`
- **验收**：切换可见性有动效；密码框不触发系统键盘截图提示异常；对比度达标。

## B3.3 密码生成器与强度指示器视觉

- **目标**：`PasswordGeneratorDialog` 与 `PasswordStrengthIndicator` 视觉统一：强度分段用品牌色阶（弱/中/强）、实时更新动画、生成器选项（长度/字符集）用 Switch/SegmentedButton 呈现。
- **涉及文件**：`lib/ui/widgets/password_generator_dialog.dart`、`password_strength_indicator.dart`、`password_suggestions_widget.dart`
- **验收**：输入变化时强度条平滑更新；生成器对话框在窄屏可用；浅/深色正常。

## B3.4 表单校验与成功反馈

- **目标**：校验错误用 `errorText` + 红色边框统一呈现，必要时加轻微抖动动效；保存成功用 SnackBar 反馈并返回列表页。
- **涉及文件**：`lib/ui/pages/add_entry_page.dart`
- **验收**：必填字段校验可见且不遮挡；保存成功/失败均有明确反馈。

## B3.5 类型选择器（新建条目入口）

- **目标**：新建条目时的类型选择从单一选择改为可视化网格（图标 + 类型名），复用 `EntryTypeHelper` 的颜色/图标；选择后直接进入对应分区表单。
- **涉及文件**：`lib/ui/pages/add_entry_page.dart` 或独立 `type_picker` 组件
- **验收**：四类类型图标/文案正确；选择有按压反馈。
