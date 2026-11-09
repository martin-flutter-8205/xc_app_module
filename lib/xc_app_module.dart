/// App 装配层：壳工程（xc_app）唯一的依赖入口。
///
/// ```dart
/// // 壳工程的 main.dart 全部内容就这么多：
/// import 'package:flutter/material.dart';
/// import 'package:xc_app_module/xc_app_module.dart';
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await bootstrap();
///   runApp(const XcApp());
/// }
/// ```
library;

export 'src/app_assembly.dart';
