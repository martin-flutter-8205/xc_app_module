import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xc_platform/xc_platform.dart';

/// 路由参数：只有 query（Map）与 extra（任意对象，业务侧强校验）两条通道。
void main() {
  RouteArgs captured = RouteArgs.empty;

  setUp(() {
    RouteTable.clear();
    captured = RouteArgs.empty;
  });
  tearDown(RouteTable.clear);

  void registerIndexPage() {
    RouteTable.register(<String, ComponentBuilder>{
      'index-page': (RouteArgs args) {
        captured = args;
        return const SizedBox.shrink();
      },
    });
  }

  test('push 显式传 query：路由名精确命中，参数原样带进页面', () {
    registerIndexPage();

    expect(RouteTable.has('index-page'), isTrue);
    expect(
      RouteTable.create(
        'index-page',
        args: const RouteArgs(query: <String, Object?>{'from': 'home', 'tab': 2}),
      ),
      isNotNull,
    );
    expect(captured.query, <String, Object?>{'from': 'home', 'tab': 2});
    expect(captured.text('from'), 'home');
    expect(captured.value<int>('tab'), 2);
  });

  test('路由名带查询串：?from=home&tab=2 解析进 query', () {
    registerIndexPage();

    expect(RouteTable.create('index-page?from=home&tab=2'), isNotNull);
    expect(captured.query, <String, Object?>{'from': 'home', 'tab': '2'});
    expect(captured.text('from'), 'home');
  });

  test('未注册返回 null，has 为 false', () {
    registerIndexPage();

    expect(RouteTable.create('nope'), isNull);
    expect(RouteTable.has('nope'), isFalse);
    expect(RouteTable.has('index-page'), isTrue);
    expect(RouteTable.size, 1);
  });

  test('显式传入的参数覆盖路由名里的同名键', () {
    registerIndexPage();

    RouteTable.create(
      'index-page?from=url',
      args: const RouteArgs(query: <String, Object?>{'from': 'home'}),
    );

    expect(captured.text('from'), 'home');
  });

  test('query 是弱类型 Map：取不到或类型不符给 null', () {
    const RouteArgs args = RouteArgs(query: <String, Object?>{'tab': 2, 'empty': null});

    expect(args['tab'], 2);
    expect(args.value<int>('tab'), 2);
    expect(args.value<String>('tab'), isNull); // 类型不符不抛错
    expect(args['none'], isNull);
    expect(args.has('tab'), isTrue);
    expect(args.has('none'), isFalse);
    expect(RouteArgs.empty.isEmpty, isTrue);
    expect(args.isEmpty, isFalse);
  });

  test('extra 不混进 query 通道：只能经 extraAs<T>() 强校验后使用', () {
    const RouteArgs args = RouteArgs(
      query: <String, Object?>{'from': 'home'},
      extra: <String, Object?>{'from': 'extra', 'scene': 'push'},
    );

    // extra 是个 Map 也不会被 [] 顺手查出来
    expect(args['from'], 'home');
    expect(args.value<String>('from'), 'home');
    expect(args['scene'], isNull);
    expect(args.has('scene'), isFalse);

    // 显式声明类型才拿得到
    expect(args.extraAs<Map<String, Object?>>()['from'], 'extra');
  });

  test('extra 强校验失败：类型不符 / 未携带都抛 RouteExtraError', () {
    const RouteArgs wrongType = RouteArgs(extra: 7);
    expect(
      () => wrongType.extraAs<String>(),
      throwsA(
        isA<RouteExtraError>()
            .having((RouteExtraError e) => e.expected, 'expected', String)
            .having((RouteExtraError e) => e.actual, 'actual', 7),
      ),
    );

    expect(() => RouteArgs.empty.extraAs<int>(), throwsA(isA<RouteExtraError>()));
    expect(RouteArgs.empty.hasExtra, isFalse);
    expect(wrongType.hasExtra, isTrue);
  });

  testWidgets('push 带参数：Component 的 route 与 argsOf 都能拿到', (WidgetTester tester) async {
    RouteTable.register(<String, ComponentBuilder>{
      'args-page': (RouteArgs route) => Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                final RouteArgs fromModal = XcRouter.argsOf(context);
                return Text(
                  'route=${route.text('from')},${route.text('tab')} '
                  'modal=${fromModal.text('from')} extra=${route.extraAs<int>()}',
                );
              },
            ),
          ),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => XcRouter.push<void>(
              context,
              'args-page',
              query: <String, Object?>{'from': 'home', 'tab': '2'},
              extra: 7,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('route=home,2 modal=home extra=7'), findsOneWidget);
  });
}
