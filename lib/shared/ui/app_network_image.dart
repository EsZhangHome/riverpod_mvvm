// lib/shared/ui/app_network_image.dart
//
// 作用：统一封装网络图片展示。
//
// 页面不要到处直接使用 CachedNetworkImage。
// 通过 AppNetworkImage 可以统一占位图、错误图、圆角和缓存策略，
// 后续如果要替换图片库，也只需要改这个文件。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// App 通用网络图片组件。
///
/// 使用场景：
/// - 首页 banner
/// - 用户头像
/// - 社区图片列表
/// - 商品 / 订单缩略图
class AppNetworkImage extends StatelessWidget {
  /// 创建统一网络图片组件。
  ///
  /// 参数说明：
  /// - [imageUrl]：完整远端地址；空字符串直接走错误占位，不请求网络；
  /// - [width]/[height]：逻辑像素尺寸，也用于推算内存解码尺寸；都不传时由父布局约束；
  /// - [fit]：图片在目标矩形中的缩放/裁剪规则，默认 cover；
  /// - [borderRadius]：可选圆角，为 null 时不额外创建 ClipRRect；
  /// - [memCacheWidth]/[memCacheHeight]：直接指定解码后的物理像素上限。通常不用传，
  ///   组件会根据 width/height × 设备像素比计算；列表缩略图建议给出明确尺寸；
  /// - [placeholder]/[errorWidget]：可替换默认加载/失败 UI。
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  /// 图片地址。
  ///
  /// 为空时不会发起网络请求，直接展示错误占位。
  final String imageUrl;

  /// 图片宽度。
  final double? width;

  /// 图片高度。
  final double? height;

  /// 图片裁剪方式。
  final BoxFit fit;

  /// 圆角。
  ///
  /// 不传时不裁剪圆角。
  final BorderRadius? borderRadius;

  /// 内存中的目标解码宽度（物理像素）。为空时根据 Widget 宽度和设备像素比计算。
  final int? memCacheWidth;

  /// 内存中的目标解码高度（物理像素）。为空时根据 Widget 高度和设备像素比计算。
  final int? memCacheHeight;

  /// 自定义加载中占位。
  final Widget? placeholder;

  /// 自定义加载失败占位。
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage(context);
    final radius = borderRadius;

    if (radius == null) {
      return image;
    }

    return ClipRRect(borderRadius: radius, child: image);
  }

  Widget _buildImage(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorView(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      // 缩略图不应按服务端原始 4K 尺寸解码。磁盘仍缓存原文件，内存只保存当前
      // 控件实际需要的像素尺寸，长列表滚动时可显著降低峰值内存。
      memCacheWidth: memCacheWidth ?? _physicalPixels(context, width),
      memCacheHeight: memCacheHeight ?? _physicalPixels(context, height),
      placeholder: (context, url) {
        return placeholder ?? _buildPlaceholder(context);
      },
      errorWidget: (context, url, error) {
        return errorWidget ?? _buildErrorView(context);
      },
    );
  }

  /// 把 [logicalPixels] 转成当前设备的物理像素，并过滤无效/未约束尺寸。
  int? _physicalPixels(BuildContext context, double? logicalPixels) {
    if (logicalPixels == null ||
        !logicalPixels.isFinite ||
        logicalPixels <= 0) {
      return null;
    }
    return (logicalPixels * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
