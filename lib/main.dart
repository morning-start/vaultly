import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routes/app_router.dart';
import 'features/auth/presentation/auto_lock_providers.dart';
import 'features/settings/settings_providers.dart';
import 'ui/theme/app_theme.dart';

/// 应用入口。
///
/// 负责完成 Flutter 框架初始化，并将路由、主题、本地化与
/// 自动锁定监听统一挂载到 `ProviderScope` 下。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VaultlyApp()));
}

/// Vaultly 根组件。
///
/// [AutoLockActivityListener] 包裹整个应用，监听全局用户活动与
/// 生命周期事件，驱动闲置自动锁定。
/// 主题模式由设置中心（[settingsProvider]）驱动并持久化。
class VaultlyApp extends ConsumerWidget {
  const VaultlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode),
    );

    return AutoLockActivityListener(
      child: MaterialApp.router(
        title: 'Vaultly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
      ),
    );
  }
}
