import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/gpu_metrics_service.dart';
import '../../domain/models/rag_stream_update.dart';
import '../../domain/repositories/rag_repository.dart';

part 'rag_event.dart';
part 'rag_state.dart';

class RagBloc extends Bloc<RagEvent, RagState> {
  final RagRepository _repository;
  final GpuMetricsService _gpuMetricsService;

  RagBloc({
    required RagRepository repository,
    required GpuMetricsService gpuMetricsService,
  })  : _repository = repository,
        _gpuMetricsService = gpuMetricsService,
        super(RagInitialState()) {
    on<IngestSkillsDirectoryEvent>(_onIngestSkillsDirectory);
    on<IngestMarkdownFilesEvent>(_onIngestMarkdownFiles);
    on<LoadIngestedFilesEvent>(_onLoadIngestedFiles);
    on<SendQuestionEvent>(_onSendQuestion);
    on<ClearKnowledgeBaseEvent>(_onClearKnowledgeBase);
  }

  Future<void> _onIngestSkillsDirectory(
    IngestSkillsDirectoryEvent event,
    Emitter<RagState> emit,
  ) async {
    emit(
      RagLoadingState(
        "Analizando recursivamente carpetas de habilidades e indexándolas...",
      ),
    );
    try {
      final fileNames =
          await _repository.ingestAgentSkillsDirectory(event.directoryPath);
      emit(FileIngestedSuccessState(fileNames));
    } catch (e) {
      emit(RagErrorState("Error al procesar las carpetas: ${e.toString()}"));
    }
  }

  Future<void> _onIngestMarkdownFiles(
    IngestMarkdownFilesEvent event,
    Emitter<RagState> emit,
  ) async {
    emit(
      RagLoadingState(
        "Procesando e indexando archivos Markdown seleccionados...",
      ),
    );
    try {
      final fileNames = await _repository.ingestFiles(event.filePaths);
      emit(FileIngestedSuccessState(fileNames));
    } catch (e) {
      emit(RagErrorState("Error al procesar los archivos: ${e.toString()}"));
    }
  }

  Future<void> _onLoadIngestedFiles(
    LoadIngestedFilesEvent event,
    Emitter<RagState> emit,
  ) async {
    try {
      final fileNames = await _repository.getIngestedFileNames();
      emit(RagLoadedFilesState(fileNames));
    } catch (e) {
      emit(RagErrorState("Error al cargar archivos indexados: ${e.toString()}"));
    }
  }

  Future<void> _onSendQuestion(
    SendQuestionEvent event,
    Emitter<RagState> emit,
  ) async {
    emit(
      RagLoadingState(
        "Consultando base de datos y conectando con Ollama...",
      ),
    );
    try {
      final currentGpu = await _gpuMetricsService.getGpuUsagePercent();
      final buffer = StringBuffer();
      double lastTps = 0.0;

      await emit.forEach<RagStreamUpdate>(
        _repository.askQuestionStream(event.question),
        onData: (update) {
          buffer.write(update.chunk);
          if (update.tokensPerSecond > 0) {
            lastTps = update.tokensPerSecond;
          }

          if (update.isDone) {
            return RagResponseSuccessState(
              question: event.question,
              answer: buffer.toString(),
              finalTps: update.tokensPerSecond > 0 ? update.tokensPerSecond : lastTps,
              gpuUsagePercent: currentGpu,
            );
          } else {
            return RagStreamingState(
              question: event.question,
              accumulatedAnswer: buffer.toString(),
              currentTps: update.tokensPerSecond > 0 ? update.tokensPerSecond : lastTps,
              gpuUsagePercent: currentGpu,
            );
          }
        },
        onError: (error, stackTrace) =>
            RagErrorState("Error al procesar la respuesta: $error"),
      );
    } catch (e) {
      emit(RagErrorState("Error al procesar la respuesta: ${e.toString()}"));
    }
  }

  Future<void> _onClearKnowledgeBase(
    ClearKnowledgeBaseEvent event,
    Emitter<RagState> emit,
  ) async {
    emit(RagLoadingState("Vaciando base de datos vectorial local..."));
    try {
      await _repository.clearKnowledgeBase();
      emit(KnowledgeBaseClearedState());
    } catch (e) {
      emit(RagErrorState("Error al limpiar la base de datos: ${e.toString()}"));
    }
  }
}
