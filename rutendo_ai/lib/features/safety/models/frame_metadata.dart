class FrameMetadata {
  const FrameMetadata({
    required this.frameWidth,
    required this.frameHeight,
    required this.modelInputWidth,
    required this.modelInputHeight,
    required this.timestampMs,
  }) : assert(frameWidth > 0),
       assert(frameHeight > 0),
       assert(modelInputWidth > 0),
       assert(modelInputHeight > 0),
       assert(timestampMs >= 0);

  final int frameWidth;
  final int frameHeight;
  final int modelInputWidth;
  final int modelInputHeight;
  final int timestampMs;
}
