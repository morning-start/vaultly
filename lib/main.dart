import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routes/app_router.dart';
import 'ui/theme/app_theme.dart';

/// 应用入口。
///
/// 负责完成 Flutter 框架初始化，并将路由、主题和本地化配置统一挂载到
/// `ProviderScope` 下，便于后续通过 Riverpod 管理全局状态。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VaultlyApp()));
}

/// Vaultly 根组件。
///
/// 统一配置应用标题、主题模式、路由配置和多语言支持。
class VaultlyApp extends ConsumerWidget {
  const VaultlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Vaultly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
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
    );
  }
}
