// 类型化消息的本地化测试。
//
// 重点不是比较所有翻译，而是证明同一个 ViewModel 消息键可以在不同 Locale 下得到
// 不同结果；这样业务状态不再被创建时的中文字符串锁死。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/l10n/app_localizations.dart';
import 'package:riverpod_mvvm/shared/localization/user_message.dart';

void main() {
  test('localized message resolves with the current locale', () {
    const message = UserMessage.localized(UserMessageKey.enterAccount);

    expect(
      message.resolve(lookupAppLocalizations(const Locale('zh'))),
      '请输入手机号',
    );
    expect(
      message.resolve(lookupAppLocalizations(const Locale('en'))),
      'Enter your phone number',
    );
  });

  test('combined login prompt resolves with the current locale', () {
    const message = UserMessage.localized(
      UserMessageKey.enterAccountAndPassword,
    );

    expect(
      message.resolve(lookupAppLocalizations(const Locale('zh'))),
      '请输入手机号和密码',
    );
    expect(
      message.resolve(lookupAppLocalizations(const Locale('en'))),
      'Enter your phone number and password',
    );
  });

  test('trusted dynamic business message remains unchanged', () {
    const message = UserMessage.text('账号已冻结');

    expect(
      message.resolve(lookupAppLocalizations(const Locale('en'))),
      '账号已冻结',
    );
    expect(message.key, isNull);
    expect(message.text, '账号已冻结');
  });
}
