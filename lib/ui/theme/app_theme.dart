import 'package:flutter/material.dart';

import 'tokens.dart';
import 'vaultly_colors.dart';

/// Vaultly 主题（「靛蓝保险库」）
///
/// 视觉基准来自 `design/tokens.css`：
/// - 深靛黑表面体系（页面底 / 卡片 / 输入框三级表面），深色为设计主态
/// - 主色 Indigo 400（dark）/ 600（light），类型色与收藏色经
///   [VaultlyColors] 扩展按明暗自适应
/// - 卡片描边为主、阴影克制（深色下靠提亮表面分层）
/// - 组件尺寸对齐原型：按钮 52、输入框 52、列表行 64、徽章 44
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final primary = isLight ? AppTokens.primaryLight : AppTokens.primaryDark;
    final primaryInk = isLight ? Colors.white : AppTokens.primaryInkDark;

    final bg = isLight ? AppTokens.lightBg : AppTokens.darkBg;
    final bgDeep = isLight ? AppTokens.lightBgDeep : AppTokens.darkBgDeep;
    final surface = isLight ? AppTokens.lightSurface : AppTokens.darkSurface;
    final surface2 = isLight ? AppTokens.lightSurface2 : AppTokens.darkSurface2;
    final surface3 = isLight ? AppTokens.lightSurface3 : AppTokens.darkSurface3;
    final textStrong = isLight
        ? AppTokens.lightTextStrong
        : AppTokens.darkTextStrong;
    final muted = isLight ? AppTokens.lightMuted : AppTokens.darkMuted;
    final faint = isLight ? AppTokens.lightFaint : AppTokens.darkFaint;
    final line = isLight ? AppTokens.lightLine : AppTokens.darkLine;
    final lineStrong = isLight
        ? AppTokens.lightLineStrong
        : AppTokens.darkLineStrong;
    final sheet = isLight ? AppTokens.lightSheet : AppTokens.darkSheet;
    final toast = isLight ? AppTokens.lightToast : AppTokens.darkToast;
    final tabBar = isLight ? AppTokens.lightTabBar : AppTokens.darkTabBar;
    final danger = isLight ? AppTokens.dangerLight : AppTokens.dangerDark;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppTokens.primaryLight,
          brightness: brightness,
          primary: primary,
          onPrimary: primaryInk,
          primaryContainer: isLight
              ? const Color(0xFFE0E7FF)
              : primary.withAlpha(36),
          onPrimaryContainer: isLight ? const Color(0xFF312E81) : primary,
          onSurface: isLight ? AppTokens.lightText : AppTokens.darkText,
          onSurfaceVariant: muted,
          outline: lineStrong,
          outlineVariant: line,
          error: danger,
        ).copyWith(
          surface: surface,
          surfaceContainerLowest: bgDeep,
          surfaceContainerLow: bg,
          surfaceContainer: surface,
          surfaceContainerHigh: surface2,
          surfaceContainerHighest: surface3,
          inverseSurface: toast,
          onInverseSurface: const Color(0xFFF4F5F9),
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
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      fontFamilyFallback: const [
        'Inter',
        'PingFang SC',
        'HarmonyOS Sans SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
      textTheme: textTheme,
      splashColor: primary.withAlpha(20),
      highlightColor: primary.withAlpha(12),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textStrong,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: textStrong, size: 24),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppTokens.navBarHeight + 8,
        elevation: 0,
        backgroundColor: tabBar,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected) ? primary : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
            size: 24,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          side: BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: muted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXL),
          side: BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: sheet,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: surface3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusXL),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: toast,
        elevation: 0,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: const Color(0xFFF4F5F9),
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusStadium),
          side: BorderSide(color: lineStrong),
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          AppTokens.spaceXL,
          AppTokens.spaceS,
          AppTokens.spaceXL,
          AppTokens.spaceL,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: primary.withAlpha(36),
        disabledColor: surface2,
        side: BorderSide(color: lineStrong),
        shape: const StadiumBorder(),
        labelStyle: textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
        secondaryLabelStyle: textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        checkmarkColor: primary,
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: inputShape,
        enabledBorder: inputShape.copyWith(borderSide: BorderSide(color: line)),
        focusedBorder: inputShape.copyWith(
          borderSide: BorderSide(color: primary),
        ),
        errorBorder: inputShape.copyWith(borderSide: BorderSide(color: danger)),
        focusedErrorBorder: inputShape.copyWith(
          borderSide: BorderSide(color: danger),
        ),
        contentPadding: AppTokens.inputPadding,
        hintStyle: textTheme.bodyMedium!.copyWith(color: faint),
        labelStyle: textTheme.labelMedium!.copyWith(color: muted),
        errorStyle: textTheme.bodySmall!.copyWith(color: danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: AppTokens.buttonPadding,
          minimumSize: const Size(64, AppTokens.buttonMinHeight),
          backgroundColor: primary,
          foregroundColor: primaryInk,
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
          backgroundColor: primary,
          foregroundColor: primaryInk,
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
          foregroundColor: textStrong,
          side: BorderSide(color: lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
        iconColor: muted,
        textColor: textStrong,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall!.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceL,
          vertical: AppTokens.spaceXS,
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryInk
              : const Color(0xFFF4F5F9),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : surface3,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : lineStrong,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: primary,
        inactiveTrackColor: surface3,
        thumbColor: primary,
        overlayColor: primary.withAlpha(30),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(100),
        thickness: WidgetStateProperty.all(6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: surface3,
        linearTrackColor: surface3,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: toast,
          borderRadius: BorderRadius.circular(AppTokens.radiusS),
          border: Border.all(color: lineStrong),
        ),
        textStyle: textTheme.bodySmall!.copyWith(
          color: const Color(0xFFF4F5F9),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  /// 统一文本主题：对齐原型 12/14/16/20/24/34 字号阶梯
  static TextTheme _buildTextTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final body = isLight ? AppTokens.lightText : AppTokens.darkText;
    final strong = isLight
        ? AppTokens.lightTextStrong
        : AppTokens.darkTextStrong;
    final base = ThemeData(brightness: brightness).textTheme;

    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontSize: AppTokens.textDisplay,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.15,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.2,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.25,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.3,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1.3,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
          bodySmall: base.bodySmall?.copyWith(fontSize: 12, height: 1.45),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        )
        .apply(bodyColor: body, displayColor: strong);
  }
}
