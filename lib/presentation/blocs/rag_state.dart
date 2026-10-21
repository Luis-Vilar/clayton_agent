part of 'rag_bloc.dart';

abstract class RagState {}

class RagInitialState extends RagState {}

class RagLoadingState extends RagState {
  final String message;
  RagLoadingState(this.message);
}

class FileIngestedSuccessState extends RagState {
  final List<String> fileNames;
  FileIngestedSuccessState(this.fileNames);
}

class RagLoadedFilesState extends RagState {
  final List<String> fileNames;
  RagLoadedFilesState(this.fileNames);
}

class RagStreamingState extends RagState {
  final String question;
  final String accumulatedAnswer;
  final double currentTps;
  final int gpuUsagePercent;

  RagStreamingState({
    required this.question,
    required this.accumulatedAnswer,
    required this.currentTps,
    required this.gpuUsagePercent,
  });
}

class RagResponseSuccessState extends RagState {
  final String question;
  final String answer;
  final double finalTps;
  final int gpuUsagePercent;

  RagResponseSuccessState({
    required this.question,
    required this.answer,
    required this.finalTps,
    required this.gpuUsagePercent,
  });
}

class RagErrorState extends RagState {
  final String errorMessage;
  RagErrorState(this.errorMessage);
}

class KnowledgeBaseClearedState extends RagState {}
