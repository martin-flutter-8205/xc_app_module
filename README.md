# xc_app_module

App 装配层（独立 git 仓库）：真正的 App 主体装配在这里完成——安装各业务 Module、
组装 MaterialApp（主题 / 全局浮层 / 首屏路由）。壳工程 `xc_app` 只调
`bootstrap()` + `runApp(const XcApp())` 两行。

## 对外出口

- `bootstrap()`：按顺序安装业务 Module 并串行跑完启动期同步任务；新增业务包只在这里加一行
- `XcApp`：App 根 Widget（MaterialApp / XcTheme.dark / 全局浮层 Stack / 首屏 = 启动页）

## 依赖

| 包 | 来源 | 说明 |
| --- | --- | --- |
| `xc_platform` / `xc_ui` | 独立 git 仓库，`git: { url, ref: main }` | 框架 |
| `xc_launch` | 独立 git 仓库，`git: { url, ref: main }` | 启动页 |
| `xc_index` | 独立 git 仓库，`git: { url, ref: main }` | 主框架 |

被 `xc_app`（壳）通过 git 依赖接入：

```yaml
xc_app_module:
  git:
    url: git@github.com:martin-flutter-8205/xc_app_module.git
    ref: main
```

## 开发

```bash
flutter pub get
flutter analyze
flutter test   # 启动链路 / 路由参数 / Model 生命周期
```
