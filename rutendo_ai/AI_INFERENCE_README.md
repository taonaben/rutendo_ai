# AI Inference on Mobile — What Worked & What Didn't

## Current Working Implementation

### Model
- **Base model:** `yolo11n.pt` (COCO-pretrained, 80 classes)
- **Export format:** ONNX opset 12, `nms=True` (bakes NonMaxSuppression into graph)
- **Output:** `(1, 300, 6)` per image — `[x1, y1, x2, y2, confidence, class_id]`
- **Filtered to 11 relevant classes:** person, bicycle, car, motorcycle, bus, truck, traffic light, stop sign, cat, dog, chair
- **Labels file:** All 80 COCO class names in `assets/models/labels.txt`

### Mobile Inference Stack
| Layer | Technology | Details |
|-------|-----------|---------|
| ONNX Runtime | `onnxruntime: ^1.4.1` (Dart FFI bindings) | Loads model from assets bytes |
| Execution Provider | `XNNPACK` | CPU-optimized ARM NEON backend, supports all ONNX ops |
| Threading | `setIntraOpNumThreads(4)` | Multi-threaded CPU inference |
| Graph Optimization | `ortEnableAll` | Full ONNX Runtime graph optimization |
| Camera | `camera: ^0.11.0` | `ResolutionPreset.medium`, `startImageStream` |
| Preprocessing | Pure Dart (YUV420→RGBA via `image` package) | Runs on main thread (~150ms) |
| Decoder | Custom Dart (~30 lines) | Reads NMS output directly, filters by class indices |

### Packaging (pubspec.yaml)
```yaml
dependencies:
  onnxruntime: ^1.4.1
  camera: ^0.11.0
  image: ^4.8.0
```

## What Did NOT Work (And Why)

### 1. Fine-tuned Model (`best.pt`, 10 Roboflow classes)
- **Problem:** NNAPI execution provider rejects the exported ONNX model containing `NonMaxSuppression` operator.
- **Root cause:** Android NNAPI drivers (Qualcomm qti-default) don't support the NMS op in the ONNX graph. The model compiles partially, but critical partitions fail with `GENERAL_FAILURE`.
- **Fix:** Switched to COCO base model + XNNPACK provider (CPU backend, supports all ONNX ops).

### 2. NNAPI Execution Provider
- **Problem:** `appendNnapiProvider(NnapiFlags.useNone)` causes session creation to fail with `model_builder.cc:425 aneuralnetworks_bad_data`.
- **Root cause:** NNAPI has limited operator coverage. ONNX NMS ops (baked into graph) are unsupported.
- **Lesson:** Only use NNAPI for simple models without NMS. For models with NMS baked in, use XNNPACK or CPU.

### 3. Background Isolate for Preprocessing
- **Problem:** `Isolate.run` with `CameraImage` data fails silently — no detections returned.
- **Root cause:** `CameraImage.planes[i].bytes` returns native-backed `Uint8List` (JNI direct byte buffer). These can't cross isolate boundaries without explicit copying via `Uint8List.fromList()`.
- **Status:** Pending — the copy + isolate approach should work but hasn't been verified.

### 4. `yolo11n.pt` without NMS (Raw Anchor Output)
- **Problem:** Output `(1, 84, 8400)` requires Dart-side decoding of 8400 anchors × 80 classes, plus NMS. Very slow on mobile CPU.
- **Fix:** `nms=True` eliminates anchor loop — output is just final detections `(1, 300, 6)`.

### 5. TFLite Export on Windows
- **Problem:** Ultralytics ≥8.4.83 requires Linux/macOS for LiteRT format TFLite export.
- **Fix:** ONNX Runtime covers mobile needs. TFLite is optional.

### 6. CoreML (iOS path)
- **Problem:** Only tested on Android. CoreML provider exists in `onnxruntime` v1.4.1 but untested.
- **Lesson:** Same pattern — `appendCoreMLProvider(CoreMLFlags.useNone)` when on iOS.

## Key Architecture Decisions

1. **ONNX opset 12** — Mobile-compatible. Opset 19 caused Reshape op failures on phone.
2. **nms=True** — Eliminates 8400-candidate loop on phone. Output is clean final detections.
3. **XNNPACK over NNAPI** — XNNPACK supports all ONNX ops and uses ARM NEON. Slightly slower than NNAPI but always works.
4. **`runAsync()` over `run()`** — `runAsync` spawns an internal `OrtIsolateSession` for background inference. Use it.
5. **Model as bytes** — `OrtSession.fromBuffer()` avoids file permission issues on Android assets.

## Current Limitations

- **Preprocessing on main thread** — YUV→RGBA + resize takes ~150ms, blocking UI. Need to either:
  - Move to isolate with `Uint8List.fromList()` byte copies
  - Use native libyuv via platform channel or `yuv_to_png` package
- **Frame throttled to ~1 FPS** — `_lastProcessed` gate at 1000ms prevents queue buildup. Remove once preprocessing is off main thread.
- **Aspect ratio mismatch** — Model processes 640×640 (square), camera preview is usually 16:9 or 4:3. Bounding box coordinates are normalized to 0-1, not corrected for aspect ratio.
- **No GPU acceleration** — XNNPACK is CPU-only. For GPU, need NNAPI-compatible model or `onnxruntime_v2` package.

## Quick Reference: Export Command

```bash
cd ai_lab
conda run -n ai-resume python src/export_model.py --model yolo11n.pt --nms
# Output: exports/yolo11n.onnx, exports/labels.txt
```

Then copy to Flutter:
```bash
Copy-Item ai_lab/exports/yolo11n.onnx rutendo_ai/assets/models/best.onnx -Force
Copy-Item ai_lab/exports/labels.txt rutendo_ai/assets/models/labels.txt -Force
```
