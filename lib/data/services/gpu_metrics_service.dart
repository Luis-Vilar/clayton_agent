import 'dart:io';

abstract class GpuMetricsService {
  Future<int> getGpuUsagePercent();
}

class GpuMetricsServiceImpl implements GpuMetricsService {
  final String? overridePath;

  GpuMetricsServiceImpl({this.overridePath});

  static const List<String> _candidateSysfsPaths = [
    '/sys/class/drm/card1/device/gpu_busy_percent',
    '/sys/class/drm/card0/device/gpu_busy_percent',
  ];

  @override
  Future<int> getGpuUsagePercent() async {
    try {
      if (overridePath != null) {
        return await _readFromPath(overridePath!);
      }

      for (final path in _candidateSysfsPaths) {
        final file = File(path);
        if (await file.exists()) {
          final value = await _readFromPath(path);
          return value;
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _readFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;

    final content = await file.readAsString();
    final parsed = int.tryParse(content.trim()) ?? 0;
    return parsed.clamp(0, 100);
  }
}
