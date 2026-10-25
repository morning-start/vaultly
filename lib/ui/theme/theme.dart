/// 主题系统导出
///
/// 统一导出设计令牌和主题配置，方便其他模块引用。
///
/// 使用方式：
/// ```dart
/// import 'package:vaultly/ui/theme/theme.dart';
///
/// // 使用设计令牌
/// const padding = AppTokens.spaceL;
///
/// // 使用主题
/// final theme = AppTheme.lightTheme;
///
/// // 使用类型色扩展
/// final typeColor = Theme.of(context).colorScheme.login;
/// ```
library;

export 'app_theme.dart';
export 'tokens.dart';
export 'vaultly_colors.dart';
