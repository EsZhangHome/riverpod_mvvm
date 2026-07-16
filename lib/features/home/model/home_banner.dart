// lib/features/home/model/home_banner.dart
//
// 作用：首页 Banner 数据模型，定义 Banner 的数据结构。
//
// 放在 features/home/model/ 的原因：
// HomeBanner 是首页模块专用的数据模型，其他模块不会用到，
// 所以由 features/home 持有，不提升为无业务归属的 shared 类型。
//
// 设计要点：
// 1. 使用 json_serializable 生成 fromJson / toJson，避免手写字段映射错误
// 2. 通过 @JsonKey(defaultValue: ...) 给关键字段提供兜底默认值
// 3. 提供 copyWith 方法，方便局部更新 banner 字段
// 4. 手写 operator== 和 hashCode，不依赖外部包
// 5. 使用 const 构造函数，所有字段都是 final

import 'package:json_annotation/json_annotation.dart';

part 'home_banner.g.dart';

/// 首页 Banner 数据模型。
///
/// 当前保留 imageUrl 字段，后续接入真实图片时不需要修改页面结构，
/// 只需要在 HomeRepository 中把模拟数据替换为真实接口数据即可。
@JsonSerializable()
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
  });

  /// Banner 唯一标识
  @JsonKey(defaultValue: '')
  final String id;

  /// Banner 标题
  @JsonKey(defaultValue: '')
  final String title;

  /// Banner 图片 URL，当前为模拟数据，接入真实后端后由接口返回
  @JsonKey(defaultValue: '')
  final String imageUrl;

  /// 从 JSON Map 创建 HomeBanner 实例。
  ///
  /// 后端字段缺失时使用空字符串兜底，保证 UI 渲染不会空指针。
  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return _$HomeBannerFromJson(json);
  }

  /// 序列化为 JSON Map。
  ///
  /// 用于数据库缓存或接口提交，字段映射由 json_serializable 生成。
  Map<String, dynamic> toJson() => _$HomeBannerToJson(this);

  /// 创建 HomeBanner 的副本，只修改指定的字段。
  ///
  /// 使用场景：局部更新 banner 信息（如只替换标题或图片）。
  HomeBanner copyWith({String? id, String? title, String? imageUrl}) {
    return HomeBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// 相等性比较：所有字段相等才认为两个 HomeBanner 相等。
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeBanner &&
            other.id == id &&
            other.title == title &&
            other.imageUrl == imageUrl;
  }

  /// 基于所有字段计算哈希值。
  @override
  int get hashCode => Object.hash(id, title, imageUrl);
}
