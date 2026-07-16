// Auth 模块对外公开的最小 API。
// 其他模块只允许依赖此文件，不应直接引用 Auth 内部目录。
export 'model/user_model.dart';
export 'view/login_page.dart';
export 'view_model/auth_view_model.dart'
    show AuthNotifier, AuthState, authProvider, currentUserIdProvider;
