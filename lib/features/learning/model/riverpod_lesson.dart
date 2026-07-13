// lib/features/learning/model/riverpod_lesson.dart
//
// 学习中心的纯 Dart Model，不依赖 Flutter、Riverpod 或路由。

enum RiverpodLessonStage { basic, async, global }

class RiverpodCodeExample {
  const RiverpodCodeExample({required this.title, required this.code});

  final String title;
  final String code;
}

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

  final RiverpodLessonStage stage;
  final String scene;
  final String apis;
  final String dataFlow;
  final String interaction;
  final String codeEntry;
  final List<RiverpodCodeExample> codeExamples;
}
