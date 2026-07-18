// 隐私升级教学场景的模块门面。
//
// App 组合层只需要配置 Provider，Mine 页面只需要展示入口；两者都通过本文件依赖
// 模块公开能力，不跨目录引用实现文件。

export 'view/privacy_upgrade_demo_card.dart' show PrivacyUpgradeDemoCard;
export 'view_model/privacy_policy_simulator.dart'
    show demoPrivacyPolicyConfigProvider;
