/*
 * Android 敏感 API 动态观察脚本（Frida）。
 *
 * 这个文件是开发工具，不会被 Gradle 或 Flutter 编译进 APK。它只记录“哪个 API
 * 在什么调用栈被调用”，不会打印 Android ID、IMEI、剪贴板内容等返回值。
 *
 * 使用前先在测试设备准备 frida-server，然后执行：
 *   frida -U -f <applicationId> \
 *     -l tool/privacy/android_privacy_hooks.js --no-pause
 *
 * 静态扫描回答“代码里有没有”，本脚本回答“测试路径中有没有真的调用”。没有日志
 * 也不能证明绝对未调用，因此提审前仍需覆盖冷启动、登录、首页、后台恢复和权限场景。
 */

'use strict';

// 必须与 Dart 的 PrivacyConsentStorageKeys、当前 ENV_PRIVACY_POLICY_VERSION 保持一致。
// shared_preferences 旧接口会给 Dart key 自动增加 flutter. 前缀，并写入下面的原生
// SharedPreferences 文件。新 key 保存 JSON 同意记录；legacyAcceptedVersionKey 只为
// 已安装旧版本升级提供兼容。政策升级时同步修改 currentPolicyVersion，旧同意便会
// 被准确归类为 pre_consent。
var PRIVACY_CONSENT_CONFIG = Object.freeze({
  preferencesFile: 'FlutterSharedPreferences',
  acceptedVersionKey: 'flutter.privacy_consent_record_v1',
  legacyAcceptedVersionKey: 'flutter.privacy_policy_accepted_version',
  currentPolicyVersion: 'starter-1'
});

setImmediate(function () {
  Java.perform(function () {
    var Log = Java.use('android.util.Log');
    var Exception = Java.use('java.lang.Exception');
    var applicationContext = null;
    var lastReportedPhase = null;

    function resolveConsentPhase() {
      // Application.attach 之前还没有可读取偏好的 Context。即使设备上可能保存过同意
      // 记录，这段最早期调用仍不能被证明发生在同意后，所以严格归为 unknown_early。
      if (applicationContext === null) {
        return {
          phase: 'unknown_early',
          decision: 'block_candidate',
          reason: 'application_context_unavailable'
        };
      }

      try {
        var preferences = applicationContext.getSharedPreferences(
          PRIVACY_CONSENT_CONFIG.preferencesFile,
          0
        );
        var encodedRecord = preferences.getString(
          PRIVACY_CONSENT_CONFIG.acceptedVersionKey,
          null
        );
        var acceptedVersion = null;
        var recordSource = 'structured_record';
        if (encodedRecord !== null) {
          try {
            var record = JSON.parse(encodedRecord.toString());
            if (record && typeof record.consentVersion === 'string') {
              acceptedVersion = record.consentVersion;
            }
          } catch (parseError) {
            return {
              phase: 'pre_consent',
              decision: 'block_candidate',
              reason: 'consent_record_invalid'
            };
          }
        } else {
          // 兼容升级前只保存版本字符串的安装。Dart Repository 下一次用户主动同意后
          // 会写入结构化记录并删除旧 key。
          acceptedVersion = preferences.getString(
            PRIVACY_CONSENT_CONFIG.legacyAcceptedVersionKey,
            null
          );
          recordSource = 'legacy_version';
        }
        var matchesCurrentVersion =
          acceptedVersion !== null &&
          acceptedVersion.toString() === PRIVACY_CONSENT_CONFIG.currentPolicyVersion;

        if (matchesCurrentVersion) {
          return {
            phase: 'post_consent',
            decision: 'review_candidate',
            reason: recordSource + '_matches'
          };
        }
        return {
          phase: 'pre_consent',
          decision: 'block_candidate',
          reason: acceptedVersion === null
            ? 'accepted_version_missing'
            : 'accepted_version_outdated'
        };
      } catch (error) {
        // 审计脚本读不到状态时不能乐观放行；不输出 error.toString，避免日志包含设备路径。
        return {
          phase: 'unknown_error',
          decision: 'block_candidate',
          reason: 'consent_state_read_failed'
        };
      }
    }

    function emit(api, detail) {
      // 每一次敏感调用都重新读取持久化值。因此用户在本进程内点击同意后，后续调用
      // 会立刻从 pre_consent 切换为 post_consent，不需要重启 Frida。
      var consent = resolveConsentPhase();
      if (consent.phase !== lastReportedPhase) {
        lastReportedPhase = consent.phase;
        console.log('PRIVACY_AUDIT_STATE ' + JSON.stringify({
          phase: consent.phase,
          decision: consent.decision,
          reason: consent.reason,
          currentPolicyVersion: PRIVACY_CONSENT_CONFIG.currentPolicyVersion,
          timestamp: new Date().toISOString()
        }));
      }
      var payload = {
        type: 'privacy_api_call',
        phase: consent.phase,
        decision: consent.decision,
        phaseReason: consent.reason,
        api: api,
        detail: detail || '',
        stack: Log.getStackTraceString(Exception.$new()),
        timestamp: new Date().toISOString()
      };
      console.log('PRIVACY_AUDIT ' + JSON.stringify(payload));
    }

    function tryHook(className, install) {
      try {
        install(Java.use(className));
      } catch (error) {
        // Android 版本或 APK 没有该类时属于正常情况，不把它误报成隐私调用。
      }
    }

    // Frida 使用 -f 冷启动 App 时会早于普通业务代码安装 Hook。Application.attach
    // 提供的 baseContext 可在 ContentProvider 初始化前读取持久化版本，从而让后续
    // 原生 SDK 自动初始化调用也能区分首次安装和已经同意后的再次启动。
    tryHook('android.app.Application', function (Application) {
      var attach = Application.attach.overload('android.content.Context');
      attach.implementation = function (context) {
        applicationContext = Java.retain(context);
        return attach.call(this, context);
      };
    });

    // Settings.Secure 是 Android ID 的常见入口。只记录被读取的 key，不记录返回值。
    tryHook('android.provider.Settings$Secure', function (Secure) {
      var getString = Secure.getString.overload(
        'android.content.ContentResolver',
        'java.lang.String'
      );
      getString.implementation = function (resolver, name) {
        emit('Settings.Secure.getString', 'key=' + name);
        return getString.call(this, resolver, name);
      };

      var getInt = Secure.getInt.overload(
        'android.content.ContentResolver',
        'java.lang.String'
      );
      getInt.implementation = function (resolver, name) {
        emit('Settings.Secure.getInt', 'key=' + name);
        return getInt.call(this, resolver, name);
      };
    });

    // 电话硬件标识。不同 Android 版本可能只存在其中一部分重载。
    tryHook('android.telephony.TelephonyManager', function (TelephonyManager) {
      ['getDeviceId', 'getImei', 'getMeid', 'getSubscriberId'].forEach(function (methodName) {
        if (!TelephonyManager[methodName]) return;
        TelephonyManager[methodName].overloads.forEach(function (overload) {
          overload.implementation = function () {
            emit('TelephonyManager.' + methodName, 'argumentCount=' + arguments.length);
            return overload.apply(this, arguments);
          };
        });
      });
    });

    tryHook('android.os.Build', function (Build) {
      if (!Build.getSerial) return;
      var getSerial = Build.getSerial.overload();
      getSerial.implementation = function () {
        emit('Build.getSerial', '');
        return getSerial.call(this);
      };
    });

    // Wi-Fi 标识。网络连接监听不需要调用这些 API，出现日志时应逐项确认用途。
    tryHook('android.net.wifi.WifiInfo', function (WifiInfo) {
      ['getMacAddress', 'getBSSID', 'getSSID'].forEach(function (methodName) {
        if (!WifiInfo[methodName]) return;
        var method = WifiInfo[methodName].overload();
        method.implementation = function () {
          emit('WifiInfo.' + methodName, '');
          return method.call(this);
        };
      });
    });

    // 剪贴板只应在用户明确粘贴时访问；脚本不打印任何剪贴板内容。
    tryHook('android.content.ClipboardManager', function (ClipboardManager) {
      ['getPrimaryClip', 'hasPrimaryClip'].forEach(function (methodName) {
        if (!ClipboardManager[methodName]) return;
        var method = ClipboardManager[methodName].overload();
        method.implementation = function () {
          emit('ClipboardManager.' + methodName, '');
          return method.call(this);
        };
      });
    });

    // 应用列表常由三方 SDK 间接读取，所以同时记录调用栈来定位真实发起方。
    tryHook('android.app.ApplicationPackageManager', function (PackageManager) {
      ['getInstalledPackages', 'getInstalledApplications'].forEach(function (methodName) {
        if (!PackageManager[methodName]) return;
        PackageManager[methodName].overloads.forEach(function (overload) {
          overload.implementation = function () {
            emit('PackageManager.' + methodName, 'argumentCount=' + arguments.length);
            return overload.apply(this, arguments);
          };
        });
      });
    });

    // Google 广告 ID 类只有相关 SDK 被打包时才存在。
    tryHook(
      'com.google.android.gms.ads.identifier.AdvertisingIdClient',
      function (AdvertisingIdClient) {
        if (!AdvertisingIdClient.getAdvertisingIdInfo) return;
        AdvertisingIdClient.getAdvertisingIdInfo.overloads.forEach(function (overload) {
          overload.implementation = function () {
            emit('AdvertisingIdClient.getAdvertisingIdInfo', '');
            return overload.apply(this, arguments);
          };
        });
      }
    );

    console.log('PRIVACY_AUDIT hooks_ready ' + JSON.stringify({
      initialPhase: 'unknown_early',
      currentPolicyVersion: PRIVACY_CONSENT_CONFIG.currentPolicyVersion
    }));
  });
});
