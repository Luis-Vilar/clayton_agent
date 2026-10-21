import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/ollama_stream_chunk.dart';

abstract class OllamaService {
  Future<List<double>> getEmbedding(String text);
  Future<String> generateResponse(String prompt);
  Stream<OllamaStreamChunk> generateResponseStream(String prompt);
}

class OllamaServiceImpl implements OllamaService {
  final Dio _dio;
  // Usamos nomic-embed-text para vectores y llama3 para generar. Cambia los modelos si usas otros.
  final String embeddingModel = 'nomic-embed-text';
  final String llmModel = 'qwen2.5-coder:7b';

  OllamaServiceImpl({required this._dio});

  @override
  Future<List<double>> getEmbedding(String text) async {
    try {
      final response = await _dio.post(
        '/embed',
        data: {'model': embeddingModel, 'input': text},
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawEmbeddings = response.data['embeddings'];
        
        if (rawEmbeddings.isNotEmpty) {
          // 1. Extraemos la primera lista interna (que es un List<dynamic>)
          final List<dynamic> firstEmbedding = rawEmbeddings.first;
          
          // 2. CORRECCIÓN: Transformamos de forma segura cada elemento dinámico a double
          return firstEmbedding.map((element) => (element as num).toDouble()).toList();
        }
      }
      throw Exception('Error al obtener embedding de Ollama');
    } catch (e) {
      throw Exception('Fallo en la comunicación con Ollama: $e');
    }
  }

  @override
  Future<String> generateResponse(String prompt) async {
    try {
      final response = await _dio.post(
        '/generate',
        data: {
          'model': llmModel,
          'prompt': prompt,
          'stream': false, // Desactivamos stream para simplificar la entrega de la respuesta completa
        },
      );

      if (response.statusCode == 200) {
        return response.data['response'] as String;
      }
      throw Exception('Error al generar respuesta de Ollama');
    } catch (e) {
      throw Exception('Fallo al generar respuesta: $e');
    }
  }

  @override
  Stream<OllamaStreamChunk> generateResponseStream(String prompt) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '/generate',
        data: {
          'model': llmModel,
          'prompt': prompt,
          'stream': true,
        },
        options: Options(responseType: ResponseType.stream),
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw Exception('Cuerpo de respuesta vacío desde Ollama');
      }

      final stopwatch = Stopwatch()..start();
      int tokenCounter = 0;

      final lineStream = responseBody.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final Map<String, dynamic> data =
            jsonDecode(trimmed) as Map<String, dynamic>;
        final String text = (data['response'] as String?) ?? '';
        final bool isDone = (data['done'] as bool?) ?? false;

        // Evitar emitir eventos vacíos que no sean de finalización
        if (text.isEmpty && !isDone) continue;

        tokenCounter++;
        double currentTps = 0.0;

        final int? evalCount = data['eval_count'] as int?;
        final int? evalDuration = data['eval_duration'] as int?;

        if (isDone &&
            evalCount != null &&
            evalDuration != null &&
            evalDuration > 0) {
          currentTps = evalCount / (evalDuration / 1e9);
        } else {
          final elapsedSeconds = stopwatch.elapsedMicroseconds / 1e6;
          if (elapsedSeconds > 0) {
            currentTps = tokenCounter / elapsedSeconds;
          }
        }

        yield OllamaStreamChunk(
          text: text,
          isDone: isDone,
          tokensPerSecond: currentTps.isNaN || currentTps.isInfinite ? 0.0 : currentTps,
          evalCount: evalCount,
          evalDurationNano: evalDuration,
        );

        if (isDone) {
          break;
        }
      }
    } catch (e) {
      throw Exception('Fallo en el streaming de Ollama: $e');
    }
  }
}
