part of 'rag_bloc.dart';

abstract class RagEvent {}

class IngestSkillsDirectoryEvent extends RagEvent {
  final String directoryPath;
  IngestSkillsDirectoryEvent(this.directoryPath);
}

class IngestMarkdownFilesEvent extends RagEvent {
  final List<String> filePaths;
  IngestMarkdownFilesEvent(this.filePaths);
}

class LoadIngestedFilesEvent extends RagEvent {}

class SendQuestionEvent extends RagEvent {
  final String question;
  SendQuestionEvent(this.question);
}

class ClearKnowledgeBaseEvent extends RagEvent {}
