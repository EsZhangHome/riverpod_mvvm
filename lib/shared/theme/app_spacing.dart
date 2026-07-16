// lib/shared/theme/app_spacing.dart
//
// 作用：集中管理 App 的间距常量，保证全 App 间距风格统一。
//
// 使用方式：
// ```dart
// const SizedBox(height: AppSpacing.lg)
// // 或
// EdgeInsets.all(AppSpacing.md)
// ```

/// App 间距常量。
///
/// 为什么需要集中管理间距：
/// 1. 保证全 App 间距风格统一，不会出现随意的 5、7、13 等非标准间距
/// 2. 设计规范变更时（如全局增加间距），只需要改这一个文件
/// 3. 命名语义化：xs < sm < md < lg < xl < xxl < xxxl，直观易读
///
/// 间距规范（基于 4px 网格系统）：
/// xs   = 4px   → 极紧凑间距（如文字与图标之间）
/// sm   = 8px   → 小间距（如列表项之间）
/// md   = 12px  → 中等间距（如卡片内边距）
/// lg   = 16px  → 大间距（如页面内容内边距）
/// xl   = 24px  → 加大间距（如区块之间）
/// xxl  = 32px  → 特大间距（如大标题与内容之间）
/// xxxl = 48px  → 超大间距（如页面顶部留白）
class AppSpacing {
  const AppSpacing._();

  /// 极紧凑间距：4px
  static const double xs = 4;

  /// 小间距：8px
  static const double sm = 8;

  /// 中等间距：12px
  static const double md = 12;

  /// 大间距：16px
  static const double lg = 16;

  /// 加大间距：24px
  static const double xl = 24;

  /// 特大间距：32px
  static const double xxl = 32;

  /// 超大间距：48px
  static const double xxxl = 48;
}
