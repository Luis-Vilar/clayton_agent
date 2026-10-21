import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';

void main() {
  group('GpuMetricsService', () {
    test('returns parsed percentage when file exists', () async {
      final tempDir = await Directory.systemTemp.createTemp('gpu_test');
      final tempFile = File('${tempDir.path}/gpu_busy_percent');
      await tempFile.writeAsString('38\n');

      final service = GpuMetricsServiceImpl(overridePath: tempFile.path);
      final usage = await service.getGpuUsagePercent();

      expect(usage, equals(38));

      await tempDir.delete(recursive: true);
    });

    test('returns 0 when file does not exist', () async {
      final service = GpuMetricsServiceImpl(overridePath: '/non/existent/path/gpu_busy_percent');
      final usage = await service.getGpuUsagePercent();

      expect(usage, equals(0));
    });

    test('clamps percentage between 0 and 100', () async {
      final tempDir = await Directory.systemTemp.createTemp('gpu_test');
      final tempFile = File('${tempDir.path}/gpu_busy_percent');
      await tempFile.writeAsString('150\n');

      final service = GpuMetricsServiceImpl(overridePath: tempFile.path);
      final usage = await service.getGpuUsagePercent();

      expect(usage, equals(100));

      await tempDir.delete(recursive: true);
    });
  });
}
