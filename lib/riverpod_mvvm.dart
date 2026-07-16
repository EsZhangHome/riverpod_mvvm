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
