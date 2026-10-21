import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/rag_repository.dart';
part 'rag_event.dart';
part 'rag_state.dart';

class RagBloc extends Bloc<RagEvent, RagState> {
  final RagRepository _repository;

  RagBloc({required this._repository}) : super(RagInitialState()) {
    on<IngestSkillsDirectoryEvent>(_onIngestSkillsDirectory);

    on<SendQuestionEvent>(_onSendQuestion);
    on<ClearKnowledgeBaseEvent>(_onClearKnowledgeBase);
  }
  // ... dentro de _onIngestFile/Directory en tu RagBloc ...
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
      // Invoca al método recursivo que creamos en el repositorio completo
      await _repository.ingestAgentSkillsDirectory(event.directoryPath);
      emit(FileIngestedSuccessState("Carpeta Completa de Skills"));
    } catch (e) {
      emit(RagErrorState("Error al procesar las carpetas: ${e.toString()}"));
    }
  }

  Future<void> _onSendQuestion(
    SendQuestionEvent event,
    Emitter<RagState> emit,
  ) async {
    emit(
      RagLoadingState(
        "Consultando base de datos y generando respuesta con Ollama...",
      ),
    );
    try {
      final answer = await _repository.askQuestion(event.question);
      emit(RagResponseSuccessState(question: event.question, answer: answer));
    } catch (e) {
      print(e.toString());
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
