// 网络基础设施的默认错误文案。
//
// ApiException 不能反向依赖 shared/localization，因此默认值由 core 自己拥有；
// AppStrings 可复用这些常量，避免同一文案出现两份定义。
abstract final class NetworkErrorMessages {
  static const requestTimeout = '请求超时，请稍后重试';
  static const requestCanceled = '请求已取消';
  static const networkError = '网络连接异常';
  static const certificateError = '证书校验失败';
  static const unknownError = '未知错误，请稍后重试';
  static const serverError = '服务器异常，请稍后重试';
}
