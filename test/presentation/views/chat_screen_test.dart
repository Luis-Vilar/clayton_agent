import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';
import 'package:clayton_agent/domain/models/rag_stream_update.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';
import 'package:clayton_agent/presentation/blocs/rag_bloc.dart';
import 'package:clayton_agent/presentation/views/chat_screen.dart';

class MockRagRepository implements RagRepository {
  final StreamController<RagStreamUpdate> _streamController =
      StreamController<RagStreamUpdate>.broadcast();

  void pushUpdate(RagStreamUpdate update) {
    _streamController.add(update);
  }

  void complete() {
    _streamController.close();
  }

  @override
  Stream<RagStreamUpdate> askQuestionStream(String question) =>
      _streamController.stream;

  @override
  Future<String> askQuestion(String question) async => 'Respuesta';

  @override
  Future<void> clearKnowledgeBase() async {}

  @override
  Future<List<String>> getIngestedFileNames() async => ['habilidad.md'];

  @override
  Future<List<String>> ingestAgentSkillsDirectory(
    String baseDirectoryPath,
  ) async => [];

  @override
  Future<List<String>> ingestFiles(List<String> filePaths) async => [];
}

class MockGpuMetricsService implements GpuMetricsService {
  @override
  Stream<int> getGpuUsageStream({
    Duration interval = const Duration(microseconds: 1),
  }) => Stream.value(50);
}

void main() {
  testWidgets(
    'ChatScreen handles rapid streaming updates without freezing or crashing',
    (WidgetTester tester) async {
      final mockRepo = MockRagRepository();
      final mockGpu = MockGpuMetricsService();
      final bloc = RagBloc(repository: mockRepo, gpuMetricsService: mockGpu);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<RagBloc>.value(
            value: bloc,
            child: const ChatScreen(),
          ),
        ),
      );

      // Initial frame
      await tester.pumpAndSettle();
      expect(find.text('Conocimiento Local'), findsOneWidget);
      expect(find.text('habilidad.md'), findsOneWidget);

      // Type a question and send
      await tester.enterText(find.byType(TextField), '¿Qué es Flutter?');
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Stream 15 fast chunks simulating Ollama tokens
      for (int i = 1; i <= 15; i++) {
        mockRepo.pushUpdate(
          RagStreamUpdate(
            chunk: 'Token$i ',
            isDone: false,
            tokensPerSecond: 40.0,
          ),
        );
        await tester.pump(const Duration(milliseconds: 25));
      }

      // Emit final done chunk
      mockRepo.pushUpdate(
        RagStreamUpdate(chunk: 'Final.', isDone: true, tokensPerSecond: 40.0),
      );
      mockRepo.complete();

      await tester.pumpAndSettle();

      // Verify rendered content contains all tokens without exceptions
      expect(find.textContaining('Token1'), findsWidgets);
      expect(find.textContaining('Final.'), findsWidgets);

      bloc.close();
    },
  );
}
