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

  // ==================== 圆角 Radius ====================
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 24;

  /// 胶囊形（chips、部分按钮）
  static const double radiusStadium = 100;

  // ==================== 组件尺寸 ====================
  static const double iconBadgeSize = 44;
  static const double stateIconContainer = 96;
  static const double stateIconSize = 48;
  static const double buttonMinHeight = 48;
  static const double cardIconSize = 24;
  static const double navBarHeight = 64;
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
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

  // ==================== 品牌色 ====================
  /// 主色 Light（Indigo 600）
  static const Color primaryLight = Color(0xFF4F46E5);

  /// 主色 Dark（Indigo 400）
  static const Color primaryDark = Color(0xFF818CF8);
}
