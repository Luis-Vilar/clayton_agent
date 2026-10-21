import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/models/ollama_stream_chunk.dart';
import 'package:clayton_agent/data/services/ollama_service.dart';

class FakeStreamAdapter implements HttpClientAdapter {
  final List<String> lines;
  FakeStreamAdapter(this.lines);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final stream = Stream<Uint8List>.fromIterable(
      lines.map((l) => Uint8List.fromList(utf8.encode('$l\n'))),
    );
    return ResponseBody(stream, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('OllamaService.generateResponseStream', () {
    test('parses streaming NDJSON lines and computes tokens per second', () async {
      final ndjsonLines = [
        jsonEncode({'model': 'qwen2.5-coder:7b', 'response': 'Hola', 'done': false}),
        jsonEncode({'model': 'qwen2.5-coder:7b', 'response': ' mundo', 'done': false}),
        jsonEncode({
          'model': 'qwen2.5-coder:7b',
          'response': '!',
          'done': true,
          'eval_count': 30,
          'eval_duration': 1000000000, // 1 second -> 30 tokens/s
        }),
      ];

      final dio = Dio();
      dio.httpClientAdapter = FakeStreamAdapter(ndjsonLines);

      final service = OllamaServiceImpl(dio: dio);
      final chunks = await service.generateResponseStream('test prompt').toList();

      expect(chunks.length, equals(3));
      expect(chunks[0].text, equals('Hola'));
      expect(chunks[0].isDone, isFalse);

      expect(chunks[1].text, equals(' mundo'));
      expect(chunks[1].isDone, isFalse);

      expect(chunks[2].text, equals('!'));
      expect(chunks[2].isDone, isTrue);
      expect(chunks[2].evalCount, equals(30));
      expect(chunks[2].tokensPerSecond, closeTo(30.0, 0.01));
    });

    test('handles eval_duration of 0 safely without NaN or crash', () async {
      final ndjsonLines = [
        jsonEncode({
          'model': 'qwen2.5-coder:7b',
          'response': 'Done',
          'done': true,
          'eval_count': 10,
          'eval_duration': 0,
        }),
      ];

      final dio = Dio();
      dio.httpClientAdapter = FakeStreamAdapter(ndjsonLines);

      final service = OllamaServiceImpl(dio: dio);
      final chunks = await service.generateResponseStream('prompt').toList();

      expect(chunks.length, equals(1));
      expect(chunks.first.isDone, isTrue);
      expect(chunks.first.tokensPerSecond.isNaN, isFalse);
    });
  });
}
