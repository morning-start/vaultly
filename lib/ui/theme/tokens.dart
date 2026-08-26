import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）
///
/// 集中定义间距、圆角、组件尺寸与动效常量，供主题与各页面统一引用。
/// 采用现代深靛蓝配色体系 + 玻璃拟态效果支持。
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
  static const double radiusCircle = 999;

  // ==================== 组件尺寸 ====================
  static const double iconBadgeSize = 44;
  static const double stateIconContainer = 96;
  static const double stateIconSize = 48;
  static const double buttonMinHeight = 48;
  static const double cardIconSize = 28;
  static const double navBarHeight = 64;
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 14,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(
    AppTokens.spaceL,
  );

  // ==================== 玻璃拟态 Blur ====================
  static const double glassBlur = 20;
  static const double glassBlurLight = 12;

  // ==================== 阴影 ====================
  static List<BoxShadow> cardShadow(Color color, {double opacity = 0.08}) => [
    BoxShadow(
      color: color.withAlpha((opacity * 255).toInt()),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: color.withAlpha((opacity * 0.5 * 255).toInt()),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glassShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(18),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  // ==================== 渐变预设 ====================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
  );

  // ==================== 动效 ====================
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 280);
  static const Duration animSlow = Duration(milliseconds: 400);
  static const Curve easeStandard = Curves.easeInOut;
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeOutQuart = Curves.easeOutQuart;
}
