// Flutter 自带的 Action 与框架的 Action 重名，这里只隐藏 Flutter 那个
import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:xc_platform/xc_platform.dart';

/// Model 生命周期：必重写的 init / 可选的 onDispose，初始化指针，dispose 里的 autoDispose。
class _LifeModel extends WModel {
  int initCount = 0;
  int disposeCount = 0;
  int released = 0;
  bool throwOnInit = false;
  bool throwOnDispose = false;

  late final Atom<int> tick = atom<int>(0);

  @override
  void init() {
    initCount++;
    if (throwOnInit) {
      throw StateError('init 失败');
    }
  }

  /// dispose 由基类独占（@nonVirtual），子类只写自己的清理，不用调 super。
  @override
  void onDispose() {
    disposeCount++;
    if (throwOnDispose) {
      throw StateError('onDispose 失败');
    }
  }

  /// addDisposable 是 @protected 的，测试里经子类转一层
  void register(VoidCallback dispose) => addDisposable(dispose);
}

class _LifeComponent extends Component<_LifeModel> {
  const _LifeComponent();

  @override
  _LifeModel createModel() => _LifeModel();

  @override
  Dispatcher dispatcher(_LifeModel model) => (Action action) {};

  @override
  Widget buildView(BuildContext context, _LifeModel model, Dispatcher dispatch) =>
      const SizedBox.shrink();
}

void main() {
  test('初始化指针：ensureInitialized 只跑一次 init', () {
    final _LifeModel model = _LifeModel();

    expect(model.initialized, isFalse);
    expect(model.ensureInitialized(), isTrue);
    expect(model.initialized, isTrue);
    expect(model.initCount, 1);

    // 幂等：重复调用不会重复初始化
    expect(model.ensureInitialized(), isTrue);
    expect(model.initCount, 1);
  });

  test('init 抛错：指针保持 false，修好后可以重试', () {
    final _LifeModel model = _LifeModel()..throwOnInit = true;

    expect(model.ensureInitialized, throwsStateError);
    expect(model.initialized, isFalse);
    expect(model.initCount, 1);

    model.throwOnInit = false;
    expect(model.ensureInitialized(), isTrue);
    expect(model.initialized, isTrue);
    expect(model.initCount, 2);
  });

  test('dispose 里的 autoDispose：登记的资源只释放一次', () {
    final _LifeModel model = _LifeModel()..ensureInitialized();
    model.register(() => model.released++);

    // 没 dispose 前不会释放
    expect(model.released, 0);

    model.dispose();
    expect(model.disposed, isTrue);
    expect(model.released, 1);
    expect(model.disposeCount, 1);

    // 幂等：重复 dispose 不会把资源释放两次
    model.dispose();
    expect(model.released, 1);
  });

  test('onDispose 抛错：autoDispose 照样跑完，登记的资源和 Atom 都不漏', () {
    final _LifeModel model = _LifeModel()
      ..ensureInitialized()
      ..throwOnDispose = true;
    model.register(() => model.released++);
    int notified = 0;
    final ReactionDisposer stop = reaction<int>((_) => model.tick.value, (_) => notified++);

    // 子类清理抛错 → 异常照旧上抛，但兜底释放已经做完
    expect(model.dispose, throwsStateError);
    expect(model.disposed, isTrue);
    expect(model.disposeCount, 1);
    expect(model.released, 1);

    model.tick.value = 1;
    expect(notified, 0); // 已释放：写值被 Atom 的释放门挡住，不再通知
    stop();
  });

  test('autoDispose 会摘掉 Atom 的订阅者', () {
    final _LifeModel model = _LifeModel()..ensureInitialized();
    int notified = 0;
    final ReactionDisposer stop = reaction<int>((_) => model.tick.value, (_) => notified++);
    addTearDown(stop);

    model.tick.value = 1;
    expect(notified, 1);

    model.dispose();
    model.tick.value = 2; // 订阅者已清空，不再通知
    expect(notified, 1);
  });

  test('已释放的 Model：指针复位，不再初始化，晚到的 disposable 立即执行', () {
    final _LifeModel model = _LifeModel()..ensureInitialized();
    model.dispose();

    expect(model.initialized, isFalse);
    expect(model.ensureInitialized(), isFalse);
    expect(model.initCount, 1);

    model.register(() => model.released++);
    expect(model.released, 1);
  });

  test('页面态是 Model 的成员：懒创建、只有一个实例，随 autoDispose 释放', () {
    final _LifeModel model = _LifeModel()..ensureInitialized();
    final PageState pageState = model.pageState;

    // 同一个实例：谁读都是它
    expect(identical(model.pageState, pageState), isTrue);
    expect(pageState.status, PageStatus.content);

    int notified = 0;
    final ReactionDisposer stop = reaction<PageSnapshot>((_) => pageState.value, (_) => notified++);
    addTearDown(stop);
    pageState.loading();
    expect(notified, 1);

    model.dispose();
    pageState.content(); // 已随 Model 释放：订阅者被摘掉，不再通知
    expect(notified, 1);
  });

  testWidgets('Component：挂载跑 init，卸载跑 dispose', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: _LifeComponent()));

    final ComponentState<_LifeModel> state =
        tester.state<ComponentState<_LifeModel>>(find.byType(_LifeComponent));
    final _LifeModel model = state.model;
    expect(model.initialized, isTrue);
    expect(model.initCount, 1);
    expect(model.disposed, isFalse);

    // 页面销毁 → ComponentState.dispose → model.dispose → autoDispose
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(model.disposed, isTrue);
    expect(model.disposeCount, 1);
  });
}
