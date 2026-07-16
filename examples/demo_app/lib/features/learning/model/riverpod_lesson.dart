// lib/features/learning/model/riverpod_lesson.dart
//
// 学习中心的纯 Dart Model，不依赖 Flutter、Riverpod 或路由。
// Repository 负责创建课程，ViewModel 负责选择阶段，View 只负责展示。

/// 三段式学习顺序。index 同时用于上一站/下一站边界判断。
enum RiverpodLessonStage { basic, async, global }

/// 一段可以在 UI 中展开、选择和复制的示例源码。
class RiverpodCodeExample {
  const RiverpodCodeExample({required this.title, required this.code});

  final String title;

  /// 原样展示的 Dart 字符串，不在 View 中拼接代码。
  final String code;
}

/// 单个阶段的完整教学内容。
class RiverpodLesson {
  const RiverpodLesson({
    required this.stage,
    required this.scene,
    required this.apis,
    required this.dataFlow,
    required this.interaction,
    required this.codeEntry,
    required this.codeExamples,
  });

  /// 唯一阶段键，用于派生 Provider 查找当前课程。
  final RiverpodLessonStage stage;

  /// 固定按照“场景 -> API -> 数据流 -> 操作 -> 源码入口”组织。
  final String scene;
  final String apis;
  final String dataFlow;
  final String interaction;
  final String codeEntry;

  /// 同一阶段可以包含多个相互独立的代码片段。
  final List<RiverpodCodeExample> codeExamples;
}
