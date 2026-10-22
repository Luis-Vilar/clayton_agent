import 'dart:io';
import 'dart:typed_data';

import 'package:clayton_agent/data/models/markdown_chunk.dart';
import 'package:clayton_agent/data/services/ollama_service.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';
import 'package:clayton_agent/data/services/vector_db_service.dart';
import 'package:path/path.dart' as p;

import '../models/rag_stream_update.dart';

abstract class RagRepository {
  Future<List<String>> ingestFiles(List<String> filePaths);
  Future<List<String>> ingestAgentSkillsDirectory(String baseDirectoryPath);
  Future<List<String>> getIngestedFileNames();
  Future<String> askQuestion(String question);
  Stream<RagStreamUpdate> askQuestionStream(String question);
  Future<void> clearKnowledgeBase();
  String get agentRole;
  Future<void> updateAgentRole(String role);
}

class RagRepositoryImpl implements RagRepository {
  final OllamaService ollamaService;
  final VectorDbService vectorDbService;
  final PromptSettingsService promptSettingsService;
  String _agentRole;

  RagRepositoryImpl({
    required this.ollamaService,
    required this.vectorDbService,
    required this.promptSettingsService,
    required String initialAgentRole,
  }) : _agentRole = initialAgentRole;

  @override
  String get agentRole => _agentRole;

  @override
  Future<void> updateAgentRole(String role) async {
    await promptSettingsService.saveAgentRole(role);
    _agentRole = role;
  }

  @override
  Future<List<String>> ingestFiles(List<String> filePaths) async {
    final List<MarkdownChunk> chunksToSave = [];
    final Set<String> processedFileNames = {};

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) continue;

      final fileName = p.basename(filePath);
      processedFileNames.add(fileName);
      final skillName = p.basenameWithoutExtension(filePath);
      final content = await file.readAsString();

      final sections = splitByMarkdownHeaders(content);
      for (final section in sections) {
        if (section.trim().length < 20) {
          continue;
        }

        final rawEmbedding = await ollamaService.getEmbedding(section);
        final float32Embedding = Float32List.fromList(rawEmbedding);

        chunksToSave.add(
          MarkdownChunk(
            filePath: filePath,
            skillName: skillName,
            content: section,
            embedding: float32Embedding,
          ),
        );
      }
    }

    if (chunksToSave.isNotEmpty) {
      await vectorDbService.saveChunks(chunksToSave);
    }

    return processedFileNames.toList();
  }

  @override
  Future<List<String>> ingestAgentSkillsDirectory(
    String baseDirectoryPath,
  ) async {
    final rootDir = Directory(baseDirectoryPath);

    if (!await rootDir.exists()) {
      throw Exception("El directorio de habilidades no existe.");
    }

    final List<String> filePaths = [];
    await for (final FileSystemEntity entity in rootDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          (entity.path.endsWith('.md') || entity.path.endsWith('.markdown'))) {
        // Ignorar directorios o archivos ocultos como .git, .dart_tool, etc.
        final parts = entity.path.split(Platform.pathSeparator);
        if (!parts.any((p) => p.startsWith('.') && p.length > 1)) {
          filePaths.add(entity.path);
        }
      }
    }

    return await ingestFiles(filePaths);
  }

  @override
  Future<List<String>> getIngestedFileNames() async {
    return await vectorDbService.getDistinctFileNames();
  }

  @override
  Future<String> askQuestion(String question) async {
    final prompt = await _buildPromptForQuestion(question);
    if (prompt == null) {
      return "No dispongo de información o patrones de diseño en mis documentos indexados para responder a esta consulta.";
    }
    return await ollamaService.generateResponse(prompt);
  }

  @override
  Stream<RagStreamUpdate> askQuestionStream(String question) async* {
    final prompt = await _buildPromptForQuestion(question);
    if (prompt == null) {
      yield RagStreamUpdate(
        chunk: "No dispongo de información o patrones de diseño en mis documentos indexados para responder a esta consulta.",
        isDone: true,
        tokensPerSecond: 0.0,
      );
      return;
    }

    final stream = ollamaService.generateResponseStream(prompt);
    await for (final chunk in stream) {
      yield RagStreamUpdate(
        chunk: chunk.text,
        isDone: chunk.isDone,
        tokensPerSecond: chunk.tokensPerSecond,
        evalCount: chunk.evalCount,
      );
      if (chunk.isDone) {
        break;
      }
    }
  }

  Future<String?> _buildPromptForQuestion(String question) async {
    final List<double> rawQueryEmbedding = await ollamaService.getEmbedding(
      question,
    );
    final Float32List queryFloat32Embedding = Float32List.fromList(
      rawQueryEmbedding,
    );
    final relevantChunks = await vectorDbService.searchSimilarChunks(
      queryFloat32Embedding,
      4,
    );

    if (relevantChunks.isEmpty) {
      return null;
    }

    final context = relevantChunks.map((c) => c.content).join("\n---\n");

    return """
$_agentRole

[Contexto de Agent Skills]
$context

[Pregunta del Usuario]
$question

Respuesta en formato Markdown (usa bloques de código si es necesario):
""";
  }

  /// Divide el Markdown inteligentemente usando los encabezados (#, ##, ###)
  List<String> splitByMarkdownHeaders(String text) {
    final RegExp headerRegex = RegExp(r'^(?:#{1,4}\s+.*)$', multiLine: true);
    final List<int> positions = [];

    for (final match in headerRegex.allMatches(text)) {
      positions.add(match.start);
    }

    if (positions.isEmpty) {
      return [text];
    }

    final List<String> sections = [];
    for (int i = 0; i < positions.length; i++) {
      final int start = positions[i];
      final int end = (i + 1 < positions.length)
          ? positions[i + 1]
          : text.length;
      sections.add(text.substring(start, end));
    }
    return sections;
  }

  @override
  Future<void> clearKnowledgeBase() async {
    await vectorDbService.clearAllChunks();
  }
}
