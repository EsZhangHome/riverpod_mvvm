// 企业底座对外暴露的最小组合 API。
//
// 为什么需要公共入口：独立示例 App 或未来的壳工程只应该依赖稳定契约，
// 不应该知道启动函数和路由契约在 app/ 内部的具体目录。以后底座重排内部文件时，
// 只要这里的导出保持不变，外部组合项目就无需跟着修改。
//
// 这里刻意不导出认证、网络、数据库等所有内部类型。真实业务仍应放在当前项目的
// features 中按层级使用；公共入口越小，底座越不容易演变成无边界的“万能 SDK”。

export 'app/bootstrap/run_application.dart' show AppRootBuilder, runApplication;
export 'app/navigation/app_route_bundle.dart' show AppRouteBundle;
export 'core/performance/performance_reporter.dart'
    show NoopPerformanceReporter, PerformanceMetric, PerformanceReporter;
export 'core/utils/crash_reporter.dart' show CrashReportingBackend;
export 'core/utils/logger.dart' show LogSink;
// Toast 是少数允许业务 View 和外部壳工程直接使用的稳定 UI 能力。这里只导出统一
// 入口和类型，不导出 StateView 等项目内部页面骨架，避免公共 API 无限制膨胀。
export 'shared/ui/app_snack_bar.dart' show AppSnackBar;
export 'shared/ui/app_toast.dart' show AppToast, AppToastPosition, AppToastType;
