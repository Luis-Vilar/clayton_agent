import 'package:flutter/material.dart';

class TelemetryBadge extends StatelessWidget {
  final double tokensPerSecond;
  final int gpuUsagePercent;
  final bool isGenerating;

  const TelemetryBadge({
    super.key,
    required this.tokensPerSecond,
    required this.gpuUsagePercent,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tpsText = tokensPerSecond > 0
        ? '${tokensPerSecond.toStringAsFixed(1)} tok/s'
        : '-- tok/s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            size: 15,
            color: isGenerating
                ? Colors.amberAccent
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            tpsText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGenerating
                  ? Colors.amberAccent
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 12,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.memory,
            size: 15,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'GPU $gpuUsagePercent%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
