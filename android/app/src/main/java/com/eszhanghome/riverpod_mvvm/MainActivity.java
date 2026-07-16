package com.eszhanghome.riverpod_mvvm;

import io.flutter.embedding.android.FlutterActivity;

/**
 * App 的 Android Flutter 宿主。
 *
 * 隐私授权流程完全由 Dart 层的状态机、登录前弹窗和全局升级弹窗管理，不需要原生
 * MethodChannel 强制杀进程。这里保持 FlutterActivity 最小实现，客户修改包名时也
 * 不需要同步维护隐私相关原生代码。
 */
public class MainActivity extends FlutterActivity {
}
