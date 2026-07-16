// lib/shared/theme/app_radius.dart
//
// 作用：集中管理 App 的圆角半径常量，保证全 App 圆角风格统一。
//
// 使用方式：
// ```dart
// BorderRadius.circular(AppRadius.card)
// ```

/// App 圆角半径常量。
///
/// 为什么需要集中管理圆角：
/// 1. 保证全 App 圆角风格统一，不会出现有的 4、有的 8、有的 12 的混乱
/// 2. 设计规范变更时（如从 8 改成 12），只需要改这一个文件
/// 3. 命名语义化：card 比 8 更能表达用途
class AppRadius {
  const AppRadius._();

  /// 卡片圆角：8px，适合 Card 组件。
  static const double card = 8;

  /// 按钮圆角：4px，适合 ElevatedButton、TextButton 等。
  static const double button = 4;

  /// 输入框圆角：4px，适合 TextField、TextFormField 等。
  static const double input = 4;
}
