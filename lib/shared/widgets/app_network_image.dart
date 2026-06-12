// lib/shared/widgets/app_network_image.dart
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
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
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
      placeholder: (context, url) {
        return placeholder ?? _buildPlaceholder(context);
      },
      errorWidget: (context, url, error) {
        return errorWidget ?? _buildErrorView(context);
      },
    );
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
