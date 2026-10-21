import 'dart:typed_data';

import '../../objectbox.g.dart';
import '../models/markdown_chunk.dart';

abstract class VectorDbService {
  Future<int> getAllChunksCount();

  Future<void> saveChunks(List<MarkdownChunk> chunks);
  Future<List<MarkdownChunk>> searchSimilarChunks(
    Float32List queryEmbedding,
    int limit,
  );

  Future<void> clearAllChunks();
}

class VectorDbServiceImpl implements VectorDbService {
  final Store _store;
  late final Box<MarkdownChunk> _box;

  VectorDbServiceImpl({required this._store}) {
    _box = _store.box<MarkdownChunk>();
  }

  @override
  Future<void> saveChunks(List<MarkdownChunk> chunks) async {
    _box.putMany(chunks);
  }

  @override
  Future<List<MarkdownChunk>> searchSimilarChunks(
    Float32List queryEmbedding,
    int limit,
  ) async {
    // 1. Usamos el método correcto: nearestNeighborsF32
    final query = _box
        .query(
          MarkdownChunk_.embedding.nearestNeighborsF32(queryEmbedding, limit),
        )
        .build();

    // 2. Usamos findWithScores() para obtener los elementos ordenados por relevancia (vecinos más cercanos)
    final List<ObjectWithScore<MarkdownChunk>> scoresResults = query
        .findWithScores();
    query.close();

    // 3. Extraemos únicamente los objetos MarkdownChunk mapeados
    return scoresResults.map((scoreResult) => scoreResult.object).toList();
  }

  @override
  Future<int> getAllChunksCount() async {
    return _box
        .count(); // Devuelve la cantidad física de registros guardados en Linux
  }

  @override
  Future<void> clearAllChunks() async {
    _box.removeAll();
  }
}
