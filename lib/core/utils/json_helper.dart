// lib/core/utils/json_helper.dart
//
// 作用：提供安全的 JSON 解析工具函数，避免类型转换异常导致页面崩溃。
//
// 设计要点：
// 1. asOrNull：类型匹配返回原值，不匹配返回 null（安全读取可选字段）
// 2. asOr：类型匹配返回原值，不匹配返回默认值（安全读取必填字段）
// 3. asList：安全解析 JSON 数组，过滤掉非 Map 元素，通过 fromJson 转为业务 Model
// 4. 所有函数都是顶层函数（非类方法），调用简洁，不需要 import 类名
//
// 使用方式：
// ```dart
// factory UserModel.fromJson(Map<String, dynamic> json) {
//   return UserModel(
//     id: asOr(json['id'], ''),           // 必填字段，给默认值
//     name: asOr(json['name'], ''),
//     avatarUrl: asOrNull<String>(json['avatarUrl']),  // 可选字段，允许 null
//   );
// }
// ```

/// 安全读取 JSON 字段，类型匹配返回原值，不匹配返回 null。
///
/// 使用场景：Model 中的可选字段（如 avatarUrl 可能为空）。
///
/// 为什么不用 `json['key'] as T?`：
/// - 如果后端返回的字段类型与预期不符（如本该是 String 但返回了 int），
///   `as T?` 会抛出 TypeError，导致页面崩溃。
/// - 使用 is 类型判断比 as 强制转换更安全。
///
/// 示例：
/// ```dart
/// final avatarUrl = asOrNull<String>(json['avatarUrl']); // String? 类型
/// ```
T? asOrNull<T>(dynamic value) {
  return value is T ? value : null;
}

/// 安全读取 JSON 字段，类型匹配返回原值，不匹配返回默认值。
///
/// 使用场景：Model 中的必填字段，但后端可能漏传或类型错误。
///
/// 与 asOrNull 的区别：
/// - asOrNull：不匹配返回 null，适合可选字段
/// - asOr：不匹配返回 defaultValue，适合必填字段
///
/// 示例：
/// ```dart
/// final id = asOr(json['id'], '');     // String 类型，默认 ''
/// final age = asOr(json['age'], 0);    // int 类型，默认 0
/// ```
T asOr<T>(dynamic value, T defaultValue) {
  return value is T ? value : defaultValue;
}

/// 安全解析 JSON 数组为业务 Model 列表。
///
/// 处理流程：
/// 1. 检查 value 是否为 List 类型，不是则返回空列表
/// 2. 过滤出类型为 `Map<String, dynamic>` 的元素
/// 3. 通过 fromJson 回调把每个 Map 转为业务 Model
///
/// 为什么不用 `(json['list'] as List).map((e) => Model.fromJson(e)).toList()`：
/// - 如果后端返回的不是 List 会抛异常
/// - 如果 List 中有非 Map 元素会抛异常
/// - 使用 whereType 和类型检查可以安全过滤
///
/// 示例：
/// ```dart
/// final banners = asList<HomeBanner>(
///   json['banners'],
///   (item) => HomeBanner.fromJson(item),
/// ); // List<HomeBanner> 类型
/// ```
List<T> asList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  // 步骤 1：检查是否为 List 类型
  if (value is! List) {
    return [];
  }
  // 步骤 2：过滤出 Map<String, dynamic> 元素，并转为 Model
  return value
      .whereType<Map<String, dynamic>>()
      .map<T>(fromJson)
      .toList(growable: false); // growable: false 优化内存，返回固定长度列表
}
