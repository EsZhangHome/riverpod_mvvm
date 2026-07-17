// Auth 模块对外公开的最小 API（也叫 barrel file / 模块门面）。
//
// 为什么不把 auth 目录全部 export：其他 feature 如果能随意引用 RemoteLoginRepository
// 或 LoginNotifier，就会绕过模块边界。这里只公开用户模型、登录入口、会话状态和
// 可替换刷新接口。LoginRepository 契约与 Provider 额外开放给 App 组合层，使品牌壳、
// Starter 或测试可以通过 override 注入实现，而不需要 import auth 内部目录。
//
// 同一个模块内部仍使用相对路径引用自己的文件，不必绕回这个公共入口。
export 'session/model/user_model.dart';
export 'session/model/auth_session.dart' show AuthSession;
export 'session/auth_network_binding.dart' show authNetworkBindingProvider;
export 'session/session_providers.dart'
    show sessionRefresherProvider, sessionStoreProvider;
export 'session/repository/session_refresher.dart' show SessionRefresher;
export 'session/repository/session_store.dart' show SessionStore;
export 'login/login_providers.dart' show loginRepositoryProvider;
export 'login/model/login_request.dart' show LoginRequest;
export 'login/model/login_response.dart' show LoginResponse;
export 'login/repository/login_repository.dart' show LoginRepository;
export 'login/view/login_page.dart';
export 'login/view_model/login_agreement_view_model.dart'
    show loginAgreementSelectionProvider;
export 'session/view_model/auth_view_model.dart'
    show
        AuthNotifier,
        AuthState,
        AuthStatus,
        authProvider,
        currentUserIdProvider;
