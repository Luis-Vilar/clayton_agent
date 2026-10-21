import 'dart:io';
import 'dart:async';

abstract class GpuMetricsService {
  Stream<int> getGpuUsageStream({Duration interval});
}

class GpuMetricsServiceImpl implements GpuMetricsService {
  final String? overridePath;

  GpuMetricsServiceImpl({this.overridePath});

  static const List<String> _candidateSysfsPaths = [
    '/sys/class/drm/card1/device/gpu_busy_percent',
    '/sys/class/drm/card0/device/gpu_busy_percent',
  ];

  @override
  Stream<int> getGpuUsageStream({
    Duration interval = const Duration(milliseconds: 500),
  }) {
    // Cria um stream que roda periodicamente com base no intervalo definido
    return Stream.periodic(
      interval,
      (_) => _readGpuNow(),
    ).asyncMap((event) => event); // Transforma o Future em valor real no stream
  }

  /// Método auxiliar interno para fazer a leitura síncrona/assíncrona instantânea
  Future<int> _readGpuNow() async {
    try {
      if (overridePath != null) {
        return await _readFromPath(overridePath!);
      }

      for (final path in _candidateSysfsPaths) {
        final file = File(path);
        if (await file.exists()) {
          return await _readFromPath(path);
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _readFromPath(String path) async {
    try {
      final file = File(path);
      final lines = await file.readAsLines();
      if (lines.isEmpty) return 0;

      final content = lines.first.trim();
      final parsed = int.tryParse(content) ?? 0;

      return parsed.clamp(0, 100);
    } catch (e) {
      print('Erro ao ler caminho da GPU ($path): $e');
      return 0;
    }
  }
}
