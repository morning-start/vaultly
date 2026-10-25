import 'package:flutter/material.dart';

import 'tokens.dart';
import 'vaultly_colors.dart';

/// Vaultly 主题（「靛蓝保险库」）
///
/// - 主色 Indigo 600（light）/ 400（dark），延续品牌资产并精炼执行
/// - 类型色、收藏色经 [VaultlyColors] 扩展按明暗自适应
/// - 卡片策略：描边为主、阴影为辅（仅按压/悬浮态）
/// - 文本主题统一字重/字距，页面不再手写 copyWith
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final primary = isLight ? AppTokens.primaryLight : AppTokens.primaryDark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryLight,
      brightness: brightness,
      primary: primary,
      onPrimary: isLight ? Colors.white : const Color(0xFF1E1B4B),
      primaryContainer:
          isLight ? const Color(0xFFE0E7FF) : const Color(0xFF312E81),
      onPrimaryContainer:
          isLight ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
    );

    final inputShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      borderSide: BorderSide.none,
    );

    final textTheme = _buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF0B1120),
      canvasColor: colorScheme.surface,
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0B1120),
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppTokens.navBarHeight + 8,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : const Color(0xFF111827),
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : const Color(0xFF16213A),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(isLight ? 76 : 60),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: isLight ? Colors.white : const Color(0xFF16213A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXL),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(isLight ? 110 : 80),
        ),
        selectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white
            : const Color(0xFF1E293B),
        border: inputShape,
        enabledBorder: inputShape.copyWith(
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(isLight ? 90 : 70),
          ),
        ),
        focusedBorder: inputShape.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: inputShape.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: inputShape.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: AppTokens.inputPadding,
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.onSurfaceVariant.withAlpha(160),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: AppTokens.buttonPadding,
          minimumSize: const Size(64, AppTokens.buttonMinHeight),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: AppTokens.buttonPadding,
          minimumSize: const Size(64, AppTokens.buttonMinHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppTokens.buttonPadding,
          minimumSize: const Size(64, AppTokens.buttonMinHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceL,
          vertical: AppTokens.spaceXS,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(60),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withAlpha(30),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(100),
        thickness: WidgetStateProperty.all(6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  /// 统一文本主题：标题紧字距、正文默认、标签加字距
  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme;
    return base
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          bodyColor: brightness == Brightness.light
              ? const Color(0xFF1E293B)
              : const Color(0xFFE2E8F0),
          displayColor: brightness == Brightness.light
              ? const Color(0xFF0F172A)
              : const Color(0xFFF1F5F9),
        );
  }
}
