class RagStreamUpdate {
  final String chunk;
  final bool isDone;
  final double tokensPerSecond;
  final int? evalCount;

  RagStreamUpdate({
    required this.chunk,
    required this.isDone,
    this.tokensPerSecond = 0.0,
    this.evalCount,
  });
}
