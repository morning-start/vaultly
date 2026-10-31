import 'package:flutter/material.dart';

import 'package:vaultly_core/vaultly_core.dart';
import 'tokens.dart';

/// Vaultly 专属色彩扩展
///
/// 条目类型色与收藏色纳入主题体系，按明暗自适应（Tailwind 600/400 双档），
/// 取代原先 `EntryTypeHelper` 中硬编码的 `Colors.blue/green/...`。
///
/// 用法：`Theme.of(context).extension<VaultlyColors>()!.login`
extension VaultlyColors on ColorScheme {
  /// 登录凭证（Sky 600 / 400）
  Color get login => brightness == Brightness.light
      ? const Color(0xFF0284C7)
      : const Color(0xFF38BDF8);

  /// 银行卡（Emerald 600 / 400）
  Color get bankCard => brightness == Brightness.light
      ? const Color(0xFF059669)
      : const Color(0xFF34D399);

  /// 安全笔记（Amber 600 / 400）
  Color get secureNote => brightness == Brightness.light
      ? const Color(0xFFD97706)
      : const Color(0xFFFBBF24);

  /// 身份信息（Violet 600 / 400）
  Color get identity => brightness == Brightness.light
      ? const Color(0xFF7C3AED)
      : const Color(0xFFA78BFA);

  /// 自定义（Slate 500 / 400）
  Color get custom => brightness == Brightness.light
      ? const Color(0xFF64748B)
      : const Color(0xFF94A3B8);

  /// 收藏星标（Amber 500 / 400）
  Color get favorite => brightness == Brightness.light
      ? const Color(0xFFF59E0B)
      : const Color(0xFFFBBF24);

  /// 成功 / 已同步态（薄荷绿，原型 --color-accent）
  Color get accent => brightness == Brightness.light
      ? AppTokens.accentLight
      : AppTokens.accentDark;

  // ==================== 中性语义色（对齐 design/tokens.css） ====================
  bool get isDark => brightness == Brightness.dark;

  /// 页面底（原型 --color-bg）
  Color get bg => isDark ? AppTokens.darkBg : AppTokens.lightBg;

  /// 更深一层：解锁页 / 启动页（原型 --color-bg-deep）
  Color get bgDeep => isDark ? AppTokens.darkBgDeep : AppTokens.lightBgDeep;

  /// 卡片表面（原型 --color-surface）
  Color get surfaceCard =>
      isDark ? AppTokens.darkSurface : AppTokens.lightSurface;

  /// 输入框 / 次级表面（原型 --color-surface-2）
  Color get surfaceAlt =>
      isDark ? AppTokens.darkSurface2 : AppTokens.lightSurface2;

  /// 按压态 / 滑轨（原型 --color-surface-3）
  Color get surfaceTrack =>
      isDark ? AppTokens.darkSurface3 : AppTokens.lightSurface3;

  /// 次要文字（原型 --color-muted）
  Color get textMuted => isDark ? AppTokens.darkMuted : AppTokens.lightMuted;

  /// 极弱说明（原型 --color-faint）
  Color get textFaint => isDark ? AppTokens.darkFaint : AppTokens.lightFaint;

  /// 边框（原型 --color-line）
  Color get hairline => isDark ? AppTokens.darkLine : AppTokens.lightLine;

  /// 强边框 / 描边按钮（原型 --color-line-strong）
  Color get hairlineStrong =>
      isDark ? AppTokens.darkLineStrong : AppTokens.lightLineStrong;

  /// 主色浅底（原型 --color-primary-soft）
  Color get primarySoft => primary.withAlpha(36);

  /// 成功浅底（原型 --color-accent-soft）
  Color get accentSoft => accent.withAlpha(36);

  /// 危险浅底（原型 --color-danger-soft）
  Color get dangerSoft => error.withAlpha(36);

  /// 底部弹层（原型 --color-surface-sheet）
  Color get sheet => isDark ? AppTokens.darkSheet : AppTokens.lightSheet;

  /// 轻提示（原型 toast 玻璃底）
  Color get toastSurface => isDark ? AppTokens.darkToast : AppTokens.lightToast;

  /// 毛玻璃底部导航底（原型 tabbar 18% / 88%）
  Color get tabBar => isDark ? AppTokens.darkTabBar : AppTokens.lightTabBar;

  /// 按类型取色
  Color entryType(EntryType type) {
    return switch (type) {
      EntryType.login => login,
      EntryType.bankCard => bankCard,
      EntryType.secureNote => secureNote,
      EntryType.identity => identity,
      EntryType.custom => custom,
    };
  }
}
