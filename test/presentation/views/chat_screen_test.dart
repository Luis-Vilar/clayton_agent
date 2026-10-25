import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';
import 'package:clayton_agent/domain/models/rag_stream_update.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';
import 'package:clayton_agent/presentation/blocs/rag_bloc.dart';
import 'package:clayton_agent/presentation/views/chat_screen.dart';

import '../../support/omarchy_test_app.dart';

class MockRagRepository implements RagRepository {
  final StreamController<RagStreamUpdate> _streamController =
      StreamController<RagStreamUpdate>.broadcast();

  String role = 'Rol de prueba';

  void pushUpdate(RagStreamUpdate update) {
    _streamController.add(update);
  }

  void complete() {
    _streamController.close();
  }

  @override
  String get agentRole => role;

  @override
  Future<void> updateAgentRole(String role) async {
    this.role = role;
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

Widget _chatApp(RagBloc bloc) => wrapInOmarchy(
  BlocProvider<RagBloc>.value(value: bloc, child: const ChatScreen()),
);

void main() {
  testWidgets(
    'ChatScreen handles rapid streaming updates without freezing or crashing',
    (WidgetTester tester) async {
      final mockRepo = MockRagRepository();
      final mockGpu = MockGpuMetricsService();
      final bloc = RagBloc(repository: mockRepo, gpuMetricsService: mockGpu);

      await tester.pumpWidget(_chatApp(bloc));

      // Initial frame
      await tester.pumpAndSettle();
      expect(find.text('clayton_agent'), findsOneWidget);
      expect(find.text('Conocimiento local'), findsOneWidget);
      expect(find.text('habilidad.md'), findsOneWidget);
      expect(find.text('1 documento'), findsOneWidget);
      expect(find.text('● local'), findsOneWidget);

      // Type a question and send
      await tester.enterText(find.byType(EditableText), '¿Qué es Flutter?');
      await tester.tap(find.byKey(const Key('chat-send')));
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
      expect(tester.takeException(), isNull);

      bloc.close();
    },
  );

  testWidgets(
    'ChatScreen opens the agent role dialog from the navigation bar',
    (WidgetTester tester) async {
      final mockRepo = MockRagRepository();
      final bloc = RagBloc(
        repository: mockRepo,
        gpuMetricsService: MockGpuMetricsService(),
      );

      await tester.pumpWidget(_chatApp(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(OmarchyIcons.codSettingsGear));
      await tester.pumpAndSettle();

      expect(find.text('Rol del agente'), findsOneWidget);
      expect(find.text('Restaurar ejemplo'), findsOneWidget);

      bloc.close();
    },
  );

  testWidgets(
    'ChatScreen hides the knowledge panel on narrow windows and reopens it',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bloc = RagBloc(
        repository: MockRagRepository(),
        gpuMetricsService: MockGpuMetricsService(),
      );

      await tester.pumpWidget(_chatApp(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Conocimiento local'), findsNothing);

      await tester.tap(find.byIcon(OmarchyIcons.codMenu));
      await tester.pumpAndSettle();

      expect(find.text('Conocimiento local'), findsOneWidget);
      expect(tester.takeException(), isNull);

      bloc.close();
    },
  );

  testWidgets(
    'ChatScreen disables sending while a response is being generated',
    (WidgetTester tester) async {
      final bloc = RagBloc(
        repository: MockRagRepository(),
        gpuMetricsService: MockGpuMetricsService(),
      );

      await tester.pumpWidget(_chatApp(bloc));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'Primera pregunta');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      final send = tester.widget<OmarchyButton>(
        find.byKey(const Key('chat-send')),
      );
      expect(send.onPressed, isNull);
      expect(tester.takeException(), isNull);

      bloc.close();
    },
  );
}
