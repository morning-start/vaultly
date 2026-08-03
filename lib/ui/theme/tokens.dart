import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）
///
/// 集中定义间距、圆角、组件尺寸与动效常量，供主题与各页面统一引用，
/// 避免硬编码散落各处，保证浅色/深色主题与各页面视觉一致。
class AppTokens {
  AppTokens._();

  // ==================== 间距 Spacing ====================
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;

  // ==================== 圆角 Radius ====================
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusCircle = 999;

  // ==================== 组件尺寸 ====================
  /// 条目卡片类型徽章尺寸
  static const double iconBadgeSize = 40;
  /// 空态/错误态图标容器尺寸
  static const double stateIconContainer = 80;
  /// 空态/错误态图标尺寸
  static const double stateIconSize = 40;
  /// 按钮最小高度
  static const double buttonMinHeight = 44;
  /// 输入框内容内边距
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
  /// 按钮内边距
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  );

  // ==================== 阴影 ====================
  /// 卡片阴影（颜色由主题按亮度提供）
  static List<BoxShadow> cardShadow(Color color) => [
    BoxShadow(
      color: color,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ==================== 动效 ====================
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);
  static const Curve easeStandard = Curves.easeInOut;
}
