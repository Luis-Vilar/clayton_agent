class OllamaStreamChunk {
  final String text;
  final bool isDone;
  final double tokensPerSecond;
  final int? evalCount;
  final int? evalDurationNano;

  OllamaStreamChunk({
    required this.text,
    required this.isDone,
    this.tokensPerSecond = 0.0,
    this.evalCount,
    this.evalDurationNano,
  });
}
