## 变更说明

<!-- 用 1～3 句话说明为什么修改、修改了什么。不要只重复文件名。 -->

## 关联任务

<!-- 例如：Closes #123。没有关联任务时写“无”。 -->

## 变更类型

- [ ] Bug 修复
- [ ] 新功能
- [ ] 架构或重构
- [ ] 测试
- [ ] 文档或 CI

## 验证记录

<!-- 勾选实际执行过的项目；不适用时说明原因。 -->

- [ ] `flutter gen-l10n && dart run tool/check_l10n.dart`
- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test tool`
- [ ] `dart run build_runner build && git diff --exit-code`
- [ ] `flutter analyze`
- [ ] `flutter test --coverage`
- [ ] `dart run tool/check_coverage.dart --minimum 70`
- [ ] 集成测试或真机手动验证

## 风险与回滚

<!-- 说明登录、存储、网络、数据库迁移、隐私或发布是否受影响，以及怎样回滚。 -->

## UI 变更

<!-- 有 UI 变更时提供截图/录屏及窄屏、深色模式、多语言验证；否则写“无”。 -->

## 提交前确认

- [ ] 变更遵守 View → ViewModel → UseCase → Repository → Service 的依赖方向
- [ ] 没有提交 Token、密码、签名文件、生产配置或用户数据
- [ ] 新增用户文案已经进入 ARB，没有在 Widget 中硬编码
- [ ] 新增平台插件已有可替换接口、生命周期说明和必要测试
- [ ] README/设计文档与代码仍然一致
- [ ] Diff 不包含与本次任务无关的大规模格式化或生成文件变化
