import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/models/markdown_chunk.dart';
import 'package:clayton_agent/data/models/ollama_stream_chunk.dart';
import 'package:clayton_agent/data/services/ollama_service.dart';
import 'package:clayton_agent/data/services/vector_db_service.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';

class MockOllamaService implements OllamaService {
  @override
  Future<List<double>> getEmbedding(String text) async {
    return List.filled(768, 0.1);
  }

  @override
  Future<String> generateResponse(String prompt) async {
    return "Respuesta simulada";
  }

  @override
  Stream<OllamaStreamChunk> generateResponseStream(String prompt) async* {
    yield OllamaStreamChunk(text: "Respuesta", isDone: false, tokensPerSecond: 10.0);
    yield OllamaStreamChunk(text: " en stream", isDone: true, tokensPerSecond: 20.0, evalCount: 15);
  }
}

class MockVectorDbService implements VectorDbService {
  final List<MarkdownChunk> stored = [];

  @override
  Future<void> saveChunks(List<MarkdownChunk> chunks) async {
    stored.addAll(chunks);
  }

  @override
  Future<List<MarkdownChunk>> searchSimilarChunks(Float32List queryEmbedding, int limit) async {
    return stored.take(limit).toList();
  }

  @override
  Future<int> getAllChunksCount() async => stored.length;

  @override
  Future<void> clearAllChunks() async => stored.clear();

  @override
  Future<List<String>> getDistinctFileNames() async {
    return stored.map((c) => c.filePath.split('/').last).toSet().toList();
  }
}

void main() {
  late MockOllamaService mockOllama;
  late MockVectorDbService mockVectorDb;
  late RagRepositoryImpl repository;

  setUp(() {
    mockOllama = MockOllamaService();
    mockVectorDb = MockVectorDbService();
    repository = RagRepositoryImpl(
      ollamaService: mockOllama,
      vectorDbService: mockVectorDb,
    );
  });

  group('RagRepository', () {
    test('splits markdown by headers and does NOT discard chunks > 40 chars', () {
      const markdown = '''# Titulo Principal
Este es un parrafo suficientemente largo que tiene mas de cuarenta caracteres para verificar que no se descarte.

## Subseccion 1
Aqui hay otro contenido importante que contiene codigo y explicaciones extensas sobre Dart y Flutter.
''';

      final sections = repository.splitByMarkdownHeaders(markdown);
      expect(sections.length, equals(2));
      expect(sections[0].contains('Titulo Principal'), isTrue);
      expect(sections[0].length, greaterThan(40));
      expect(sections[1].contains('Subseccion 1'), isTrue);
      expect(sections[1].length, greaterThan(40));
    });

    test('ingestFiles correctly reads files, embeds, and saves chunks', () async {
      final tempDir = await Directory.systemTemp.createTemp('rag_repo_test');
      final file1 = File('${tempDir.path}/doc1.md');
      await file1.writeAsString('''# Doc Uno
Este parrafo tiene bastante texto descriptivo para ser indexado por el repositorio.
''');

      final fileNames = await repository.ingestFiles([file1.path]);

      expect(fileNames, contains('doc1.md'));
      expect(mockVectorDb.stored.isNotEmpty, isTrue);
      expect(mockVectorDb.stored.first.filePath, equals(file1.path));

      await tempDir.delete(recursive: true);
    });

    test('askQuestionStream streams updates and completes with metrics', () async {
      mockVectorDb.stored.add(
        MarkdownChunk(
          filePath: '/path/doc.md',
          skillName: 'general',
          content: 'Contexto relevante sobre Flutter',
          embedding: Float32List(768),
        ),
      );

      final updates = await repository.askQuestionStream('¿Cómo funciona?').toList();

      expect(updates.length, equals(2));
      expect(updates[0].chunk, equals('Respuesta'));
      expect(updates[0].isDone, isFalse);
      expect(updates[1].chunk, equals(' en stream'));
      expect(updates[1].isDone, isTrue);
      expect(updates[1].tokensPerSecond, equals(20.0));
    });
  });
}
