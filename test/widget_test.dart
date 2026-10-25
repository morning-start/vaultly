// 基础 Flutter widget 冒烟测试。
//
// 验证应用能完成启动并渲染出首屏（SplashPage 的品牌文本）。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaultly/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: VaultlyApp()));

    // Splash 首帧渲染（auth 初始化是异步的，只 pump 必要帧数）。
    await tester.pump();

    // 验证首屏渲染出品牌文本（SplashPage 标题）。
    expect(find.text('Vaultly'), findsOneWidget);
  });
}
