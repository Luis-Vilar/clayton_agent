import 'package:dio/dio.dart';

abstract class OllamaService {
  Future<List<double>> getEmbedding(String text);
  Future<String> generateResponse(String prompt);
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
}
