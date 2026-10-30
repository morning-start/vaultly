import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）
///
/// 集中定义间距、圆角、组件尺寸与动效常量，供主题与各页面统一引用。
/// 采用「靛蓝保险库」配色体系：类型色均为 Tailwind 600/400 双档，
/// 明暗模式下对比度均达标。
class AppTokens {
  AppTokens._();

  // ==================== 间距 Spacing ====================
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;
  static const double spaceXXXL = 48;

  // ==================== 圆角 Radius（对齐原型 10/14/18/24） ====================
  static const double radiusS = 10;
  static const double radiusM = 14;
  static const double radiusL = 18;
  static const double radiusXL = 24;

  /// 胶囊形（chips、部分按钮）
  static const double radiusStadium = 100;

  // ==================== 组件尺寸（对齐原型 44/48/52/64/83） ====================
  static const double iconBadgeSize = 44;
  static const double iconBadgeLarge = 56;
  static const double badgeRadius = 13;
  static const double badgeRadiusLarge = 16;
  static const double stateIconContainer = 96;
  static const double stateIconSize = 48;
  static const double buttonMinHeight = 52;
  static const double inputHeight = 52;
  static const double searchHeight = 48;
  static const double listRowMinHeight = 64;
  static const double tabBarHeight = 83;
  static const double fabSize = 56;
  static const double cardIconSize = 24;
  static const double navBarHeight = 52;
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  );
  static const EdgeInsets listRowPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 14,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(spaceL);

  // ==================== 阴影 ====================
  /// 卡片轻阴影（仅按压/悬浮态使用；静止态用描边）
  static List<BoxShadow> cardShadow(Color color, {double opacity = 0.08}) {
    return [
      BoxShadow(
        color: color.withAlpha((opacity * 255).round()),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // ==================== 动效 ====================
  static const Duration animTap = Duration(milliseconds: 100);
  static const Duration animFast = Duration(milliseconds: 180);
  static const Duration animNormal = Duration(milliseconds: 240);
  static const Duration animSlow = Duration(milliseconds: 400);

  static const Curve easeStandard = Curves.easeOut;
  static const Curve easeOutBack = Curves.easeOutBack;

  /// 列表入场 stagger 间隔
  static const Duration staggerInterval = Duration(milliseconds: 30);

  /// stagger 上限项数（防止长列表动画拖沓）
  static const int staggerMaxItems = 8;

  // ==================== 字体 ====================
  /// 等宽字体族（密码 / TOTP / 卡号 / 密钥）
  static const String monoFamily = 'JetBrainsMono';

  /// TOTP 大码等展示数字的字号（原型 --text-display: 34px）
  static const double textDisplay = 34;

  // ==================== 品牌色 ====================
  /// 主色 Light（Indigo 600）
  static const Color primaryLight = Color(0xFF4F46E5);

  /// 主色 Dark（Indigo 400）
  static const Color primaryDark = Color(0xFF818CF8);

  /// 主色按钮上的深字（dark 档，原型 --color-primary-ink）
  static const Color primaryInkDark = Color(0xFF0C0E1C);

  /// 成功 / 同步态薄荷绿（原型 --color-accent）
  static const Color accentLight = Color(0xFF0D9488);
  static const Color accentDark = Color(0xFF58D8AE);

  /// 危险态（原型 --color-danger）
  static const Color dangerLight = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF75D59);

  /// 警示态（原型 --color-warning）
  static const Color warningLight = Color(0xFFD97706);
  static const Color warningDark = Color(0xFFEEBC4A);

  // ==================== 中性色（oklch → sRGB，对应 design/tokens.css） ====================
  /// dark：页面底 / 更深底（解锁页）
  static const Color darkBg = Color(0xFF0C0E16);
  static const Color darkBgDeep = Color(0xFF06070E);

  /// dark：卡片 / 输入框与次级表面 / 按压态与滑轨
  static const Color darkSurface = Color(0xFF141720);
  static const Color darkSurface2 = Color(0xFF1E212C);
  static const Color darkSurface3 = Color(0xFF292C39);

  /// dark：正文 / 次要文字 / 极弱说明
  static const Color darkText = Color(0xFFE9EBF1);
  static const Color darkTextStrong = Color(0xFFF4F5F9);
  static const Color darkMuted = Color(0xFF8F929E);
  static const Color darkFaint = Color(0xFF60636D);

  /// dark：边框 / 强边框
  static const Color darkLine = Color(0xFF262833);
  static const Color darkLineStrong = Color(0xFF343744);

  /// dark：毛玻璃 tabbar / 底部弹层 / 轻提示
  static const Color darkTabBar = Color(0xFF0F111A);
  static const Color darkSheet = Color(0xFF181A24);
  static const Color darkToast = Color(0xFF2B2D38);

  /// light：同一套语义的浅色档（Slate 系）
  static const Color lightBg = Color(0xFFF6F7FB);
  static const Color lightBgDeep = Color(0xFFEDEFF6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF1F3F9);
  static const Color lightSurface3 = Color(0xFFE6E9F2);
  static const Color lightText = Color(0xFF171A23);
  static const Color lightTextStrong = Color(0xFF0B0D14);
  static const Color lightMuted = Color(0xFF5E6473);
  static const Color lightFaint = Color(0xFF8A90A0);
  static const Color lightLine = Color(0xFFE3E6EF);
  static const Color lightLineStrong = Color(0xFFCFD4E2);
  static const Color lightTabBar = Color(0xFFFBFBFD);
  static const Color lightSheet = Color(0xFFFFFFFF);
  static const Color lightToast = Color(0xFF2B2D38);
}
