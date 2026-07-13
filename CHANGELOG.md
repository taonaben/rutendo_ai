# Changelog

## [Unreleased]
### Added
- Full AI4I submission documentation (proposal, business model, dataset card, benchmark guide, architecture diagram)
- Project ID: RUT-AI4I-DEV-001

## [1.0.0] - 2026-07
### Added
- Initial Flutter MVP with camera capture and TFLite object detection
- Background isolate for preprocessing and TFLite inference with GPU delegate (GpuDelegateV2) + XNNPack CPU fallback
- RawYoloDecoder with column-major NCHW output parsing and NMS
- SimpleTracker for cross-frame object tracking with persistent IDs
- MotionEstimator for velocity and trajectory estimation
- Risk engine with zone classification, distance estimation, and priority scoring
- Audio cue system with WAV assets (static_tick, dynamic_tick, critical_chirp) via flutter_soloud
- Performance HUD showing preprocess/inference/decode/total timing
- Calibration harness database and store for user-specific tuning
- Unit tests (21 passing): risk engine, tracker, motion estimator, audio engine, detection parser
- YOLO11n pruned COCO model (11 classes) exported to TFLite format
- YOLO11n fine-tuned Roboflow model (10 classes) in development
- Python AI lab: model training, pruning, and export pipelines