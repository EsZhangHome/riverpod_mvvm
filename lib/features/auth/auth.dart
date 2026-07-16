// Auth 模块对外公开的最小 API（也叫 barrel file / 模块门面）。
//
// 为什么不把 auth 目录全部 export：其他 feature 如果能随意引用 LoginRepositoryImpl
// 或 LoginNotifier，就会绕过模块边界。这里只公开用户模型、页面、会话状态和可替换
// 刷新接口；模块内部以后换目录或实现，调用方不受影响。
//
// 同一个模块内部仍使用相对路径引用自己的文件，不必绕回这个公共入口。
export 'model/user_model.dart';
export 'model/auth_session.dart' show AuthSession;
export 'auth_network_binding.dart' show authNetworkBindingProvider;
export 'auth_providers.dart'
    show sessionRefresherProvider, sessionStoreProvider;
export 'repository/session_refresher.dart' show SessionRefresher;
export 'repository/session_store.dart' show SessionStore;
export 'view/login_page.dart';
export 'view_model/auth_view_model.dart'
    show
        AuthNotifier,
        AuthState,
        AuthStatus,
        authProvider,
        currentUserIdProvider;
