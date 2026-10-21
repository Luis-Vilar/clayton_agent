part of 'rag_bloc.dart';

abstract class RagState {}

class RagInitialState extends RagState {}

// Estado de carga (procesando archivo o pensando respuesta)
class RagLoadingState extends RagState {
  final String message;
  RagLoadingState(this.message);
}

// Éxito al indexar un nuevo documento Markdown
class FileIngestedSuccessState extends RagState {
  final String fileName;
  FileIngestedSuccessState(this.fileName);
}

// Respuesta lista para mostrar en la interfaz de usuario
class RagResponseSuccessState extends RagState {
  final String question;
  final String answer;
  RagResponseSuccessState({required this.question, required this.answer});
}

// Manejo de errores globales (ej: Ollama apagado)
class RagErrorState extends RagState {
  final String errorMessage;
  RagErrorState(this.errorMessage);
}


class KnowledgeBaseClearedState extends RagState {}
