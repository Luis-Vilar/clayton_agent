import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';
import 'package:clayton_agent/domain/models/rag_stream_update.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';
import 'package:clayton_agent/presentation/blocs/rag_bloc.dart';
import 'package:clayton_agent/presentation/widgets/agent_role_dialog.dart';
import '../../support/omarchy_test_app.dart';

class FakeRepo implements RagRepository {
  String role = 'Rol inicial';
  bool failUpdateRole = false;

  @override
  String get agentRole => role;

  @override
  Future<void> updateAgentRole(String role) async {
    if (failUpdateRole) throw Exception('save failed');
    this.role = role;
  }

  @override
  Future<List<String>> ingestFiles(List<String> filePaths) async => [];

  @override
  Future<List<String>> ingestAgentSkillsDirectory(String baseDirectoryPath) async => [];

  @override
  Future<List<String>> getIngestedFileNames() async => [];

  @override
  Future<String> askQuestion(String question) async => '';

  @override
  Stream<RagStreamUpdate> askQuestionStream(String question) => const Stream.empty();

  @override
  Future<void> clearKnowledgeBase() async {}
}

class FakeGpu implements GpuMetricsService {
  @override
  Stream<int> getGpuUsageStream({Duration interval = const Duration(microseconds: 0)}) =>
      Stream.value(0);
}

void main() {
  testWidgets('shows the current role, restores the example and saves the edited role',
      (tester) async {
    final repo = FakeRepo();
    final bloc = RagBloc(repository: repo, gpuMetricsService: FakeGpu());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      wrapInOmarchy(
        BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) => Center(
              child: OmarchyButton(
                onPressed: () => showAgentRoleDialog(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Rol inicial'), findsOneWidget);

    await tester.tap(find.text('Restaurar ejemplo'));
    await tester.pumpAndSettle();
    expect(find.text(defaultAgentRole), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Rol editado');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(repo.role, 'Rol editado');
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('save is disabled until the role is loaded', (tester) async {
    final repo = FakeRepo();
    final bloc = RagBloc(repository: repo, gpuMetricsService: FakeGpu());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      wrapInOmarchy(
        BlocProvider.value(value: bloc, child: const AgentRoleDialog()),
      ),
    );

    final saveButton = tester.widget<OmarchyButton>(
      find.widgetWithText(OmarchyButton, 'Guardar'),
    );
    expect(saveButton.onPressed, isNull);
  });
}
