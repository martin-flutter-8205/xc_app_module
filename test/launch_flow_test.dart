import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xc_launch/xc_launch.dart';
import 'package:xc_platform/xc_platform.dart';
import 'package:xc_app_module/xc_app_module.dart';
import 'package:xc_ui/xc_ui.dart';

/// 启动页 → 主框架的整条链路：拉配置、倒计时、跳过、replace 不留栈。
void main() {
  setUp(() {
    ModuleRegistry.reset();
    // mock 延迟归零：测试不用等真实的 80ms
    XcHttp.install(const MockXcHttpClient(latency: Duration.zero));
  });

  /// 起 App 并等启动页把配置拉回来（首帧 loading，之后内容态）。
  Future<void> pumpShell(WidgetTester tester) async {
    // bootstrap 里有真实延时（syncTask），必须放到 runAsync 里跑
    await tester.runAsync(bootstrap);
    await tester.pumpWidget(const XcApp());
    await tester.pump(); // init → onBoot 发出请求
    await tester.pump(const Duration(milliseconds: 16)); // mock 回来 → 切内容态
    await tester.pump(); // 兜底一帧
  }

  testWidgets('启动页：拉配置 → 倒计时走完 → 替换成主框架', (WidgetTester tester) async {
    await pumpShell(tester);

    expect(find.text('响彻星空'), findsOneWidget);
    expect(find.text('让声音抵达星空'), findsOneWidget);
    expect(find.text('3 秒后进入'), findsOneWidget);

    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(); // finished → 出栈门
    await tester.pumpAndSettle();

    // 启动页被 replace 掉，主框架的 tabbar 出现
    expect(find.byType(XcBottomTabBar), findsOneWidget);
    expect(find.text('今晚的星空电台'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
  });

  testWidgets('点跳过：不等倒计时，直接进主框架', (WidgetTester tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('launch-skip')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(XcBottomTabBar), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
  });

  testWidgets('主框架是根：进主框架后没有可回退的页面', (WidgetTester tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('launch-skip')));
    await tester.pumpAndSettle();

    final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('业务包的资源在 App 里能加载：路径带 packages/ 前缀', (WidgetTester tester) async {
    await pumpShell(tester);

    // 这是真实场景：root 是 shell，xc_launch 是依赖包。
    // 包内写 'assets/images/...' 会 404，必须走生成的常量。
    final ByteData data = await rootBundle.load(XcLaunchAssets.imagesLaunchMark);
    expect(data.lengthInBytes, greaterThan(0));
    expect(XcLaunchAssets.imagesLaunchMark, startsWith('packages/xc_launch/'));
  });
}
