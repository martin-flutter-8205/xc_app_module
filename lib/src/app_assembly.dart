import 'package:flutter/material.dart';
import 'package:xc_index/xc_index.dart';
import 'package:xc_launch/xc_launch.dart';
import 'package:xc_platform/xc_platform.dart';
import 'package:xc_ui/xc_ui.dart';

/// 装配：App 主体在这里拼装，壳工程（xc_app）只调 [bootstrap] + `runApp([XcApp])`。
///
/// 顺序有意义：`runSyncTasks` 按注册顺序串行 await，启动包排在最前，
/// 它的预热跑完才轮到后面的包。新增业务包只在这里加一行。
Future<void> bootstrap() async {
  ModuleRegistry.install(LaunchModule());
  ModuleRegistry.install(IndexModule());
  await ModuleRegistry.runSyncTasks();
}

/// App 根：装配 Module + 提供 MaterialApp / 主题 / 全局浮层。
class XcApp extends StatelessWidget {
  const XcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '响彻星空',
      debugShowCheckedModeBanner: false,
      theme: XcTheme.dark,
      // 第一屏是启动页：倒计时结束由启动页自己 replace 成主框架
      home: RouteTable.create(LaunchRoutes.page),
      builder: (BuildContext context, Widget? child) => Stack(
        children: <Widget>[
          if (child != null) child,
          // 所有业务包声明的全局浮层都叠在页面之上，切路由也不会掉
          ...ModuleRegistry.overlays,
        ],
      ),
    );
  }
}
