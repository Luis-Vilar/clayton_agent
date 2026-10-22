import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';
import 'package:clayton_agent/domain/models/rag_stream_update.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';
import 'package:clayton_agent/presentation/blocs/rag_bloc.dart';

class FakeRagRepository implements RagRepository {
  List<String> files = ['initial.md'];

  @override
  Future<List<String>> ingestFiles(List<String> filePaths) async {
    final names = filePaths.map((p) => p.split('/').last).toList();
    files.addAll(names);
    return names;
  }

  @override
  Future<List<String>> ingestAgentSkillsDirectory(
    String baseDirectoryPath,
  ) async {
    files.add('dir_doc.md');
    return ['dir_doc.md'];
  }

  @override
  Future<List<String>> getIngestedFileNames() async => files;

  @override
  Future<String> askQuestion(String question) async => 'Respuesta directa';

  @override
  Stream<RagStreamUpdate> askQuestionStream(String question) async* {
    yield RagStreamUpdate(chunk: 'Hola', isDone: false, tokensPerSecond: 15.0);
    yield RagStreamUpdate(
      chunk: ' Flutter',
      isDone: true,
      tokensPerSecond: 25.0,
    );
  }

  @override
  Future<void> clearKnowledgeBase() async => files.clear();
}

class FakeGpuMetricsService implements GpuMetricsService {
  int usage = 42;

  @override
  Stream<int> getGpuUsageStream({
    Duration interval = const Duration(microseconds: 0),
  }) => Stream.value(usage);
}

void main() {
  late FakeRagRepository fakeRepo;
  late FakeGpuMetricsService fakeGpu;
  late RagBloc bloc;

  setUp(() {
    fakeRepo = FakeRagRepository();
    fakeGpu = FakeGpuMetricsService();
    bloc = RagBloc(repository: fakeRepo, gpuMetricsService: fakeGpu);
  });

  tearDown(() {
    bloc.close();
  });

  group('RagBloc', () {
    test(
      'emits FileIngestedSuccessState on IngestMarkdownFilesEvent',
      () async {
        final expectedStates = [
          isA<RagLoadingState>(),
          isA<FileIngestedSuccessState>().having(
            (s) => s.fileNames,
            'fileNames',
            contains('file_a.md'),
          ),
        ];

        expectLater(bloc.stream, emitsInOrder(expectedStates));

        bloc.add(IngestMarkdownFilesEvent(['/test/path/file_a.md']));
      },
    );

    test('emits RagLoadedFilesState on LoadIngestedFilesEvent', () async {
      expectLater(
        bloc.stream,
        emits(
          isA<RagLoadedFilesState>().having(
            (s) => s.fileNames,
            'fileNames',
            contains('initial.md'),
          ),
        ),
      );

      bloc.add(LoadIngestedFilesEvent());
    });

    test('emits RagStreamingState and RagResponseSuccessState on SendQuestionEvent', () async {
      final expectedStates = [
        isA<RagLoadingState>(),
        isA<RagStreamingState>()
            .having((s) => s.accumulatedAnswer, 'accumulatedAnswer', 'Hola')
            .having((s) => s.gpuUsagePercent, 'gpuUsagePercent', 42),
        isA<RagResponseSuccessState>()
            .having((s) => s.answer, 'answer', 'Hola Flutter')
            .having((s) => s.finalTps, 'finalTps', 25.0)
            .having((s) => s.gpuUsagePercent, 'gpuUsagePercent', 0),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(SendQuestionEvent('¿Cómo estás?'));
    });
  });
}
