import 'dart:io';
import 'dart:typed_data';

import 'package:clayton_agent/data/models/markdown_chunk.dart';
import 'package:clayton_agent/data/services/ollama_service.dart';
import 'package:clayton_agent/data/services/vector_db_service.dart';
import 'package:path/path.dart' as p;

abstract class RagRepository {
  Future<void> ingestAgentSkillsDirectory(String baseDirectoryPath);
  Future<String> askQuestion(String question);
  Future<void> clearKnowledgeBase();
}

class RagRepositoryImpl implements RagRepository {
  final OllamaService _ollamaService;
  final VectorDbService _vectorDbService;

  new({required this._ollamaService, required this._vectorDbService});

  @override
  Future<String> askQuestion(String question) async {
    final totalEnBd = await _vectorDbService.getAllChunksCount();
    print(
      "📂 Total de fragmentos disponibles en ObjectBox para buscar: $totalEnBd",
    );

    // 1. Vectorizar la pregunta del desarrollador
    final List<double> rawQueryEmbedding = await _ollamaService.getEmbedding(
      question,
    );
    final Float32List queryFloat32Embedding = Float32List.fromList(
      rawQueryEmbedding,
    );

    // 2. Búsqueda vectorial KNN (vamos a pedirle 4 fragmentos)
    final relevantChunks = await _vectorDbService.searchSimilarChunks(
      queryFloat32Embedding,
      4,
    );

    if (relevantChunks.isEmpty) {
      return "No dispongo de información o patrones de diseño en mis documentos indexados para responder a esta consulta.";
    }

    // DIAGNÓSTICO: Imprimir en consola qué fragmentos de tus plugins se están enviando al LLM
    print("📋 TEXTO RECUPERADO DE OBJECTBOX ENVIADO A QWEN:");
    for (int i = 0; i < relevantChunks.length; i++) {
      print(
        "--- Fragmento \${i + 1} (Skill: \${relevantChunks[i].skillName}) ---",
      );
      print(
        relevantChunks[i].content.length > 200
            ? "\${relevantChunks[i].content.substring(0, 200)}..."
            : relevantChunks[i].content,
      );
    }

    // Unir los fragmentos encontrados
    final context = relevantChunks.map((c) => c.content).join("\n---\n");

    // 3. Ajuste de Prompt flexible pero seguro para Qwen 2.5 Coder
    final prompt =
        """
Responde la siguiente pregunta técnica sobre Dart/Flutter basándote en la documentación y los plugins provistos en el contexto. Si encuentras código relevante o patrones de arquitectura en el contexto, úsalos para armar un ejemplo práctico.

[Contexto de Agent Skills]
$context

[Pregunta del Usuario]
$question

Respuesta en formato Markdown (usa bloques de código si es necesario):
""";

    // 4. Obtener la respuesta generada por Qwen 2.5 Coder
    return await _ollamaService.generateResponse(prompt);
  }

  /// Escanea de forma recursiva la carpeta de Agent Skills e indexa todo su contenido
  @override
  Future<void> ingestAgentSkillsDirectory(String baseDirectoryPath) async {
    final rootDir = Directory(baseDirectoryPath);

    if (!await rootDir.exists())
      throw Exception("El directorio de habilidades no existe.");

    List<MarkdownChunk> chunksToSave = [];

    // 1. Listar de forma recursiva todos los archivos dentro de las carpetas de habilidades
    await for (final FileSystemEntity entity in rootDir.list(recursive: true)) {
      // Filtrar para procesar solo archivos Markdown (.md o .SKILL.md)
      if (entity is File &&
          (entity.path.endsWith('.md') || entity.path.endsWith('.markdown'))) {
        final String content = await entity.readAsString();

        // Obtener el nombre de la carpeta contenedora como el nombre de la habilidad
        final List<String> pathParts = p.split(entity.path);
        // Suponiendo una estructura .agents/skills/nombre-skill/archivo.md
        final String skillName = pathParts.length > 2
            ? pathParts[pathParts.length - 2]
            : "General";

        // 2. Dividir el documento respetando los bloques lógicos de Markdown (por secciones de encabezados)
        final List<String> sections = _splitByMarkdownHeaders(content);

        for (var section in sections) {
          if (section.trim().length > 40) {
            continue;
          }
          final rawEmbedding = await _ollamaService.getEmbedding(section);
          final Float32List float32embedding = Float32List.fromList(
            rawEmbedding,
          );

          chunksToSave.add(
            MarkdownChunk(
              filePath: entity.path,
              skillName: skillName,
              content: section,
              embedding: float32embedding,
            ),
          );
        }
      }
    }

    // 4. Guardar masivamente en ObjectBox
    if (chunksToSave.isNotEmpty) {
      await _vectorDbService.saveChunks(chunksToSave);
      print("🚀 ¡INGESTA COMPLETADA EXITOSAMENTE!");
      print("📊 Chunks procesados en esta tanda: ${chunksToSave.length}");
    }
  }

  /// Divide el Markdown inteligentemente usando los encabezados (#, ##, ###)
  /// Esto evita romper códigos de Flutter a la mitad
  List<String> _splitByMarkdownHeaders(String text) {
    // Expresión regular que busca encabezados Markdown de nivel 1 a 4
    final RegExp headerRegex = RegExp(r'^(?:#{1,4}\s+.*)$', multiLine: true);
    final List<int> positions = [];

    for (final match in headerRegex.allMatches(text)) {
      positions.add(match.start);
    }

    if (positions.isEmpty)
      return [text]; // Si no tiene headers, se devuelve entero

    List<String> sections = [];
    for (int i = 0; i < positions.length; i++) {
      int start = positions[i];
      int end = (i + 1 < positions.length) ? positions[i + 1] : text.length;
      sections.add(text.substring(start, end));
    }
    return sections;
  }

   @override
  Future<void> clearKnowledgeBase() async {
    await _vectorDbService.clearAllChunks();
  }
}
