# Rutendo AI — AI Lab (Person 2)

Raw detection pipeline for the sensory substitution navigation assistant.

## Pipeline

Video → YOLO detection → JSON output per detection

## Setup

```bash
conda activate ai-resume
pip install -r requirements.txt
```

## Usage

Process every frame, output JSON to stdout:

```bash
python src/prototype_detection.py -i videos/UrbanMtbPOV.mp4
```

Output (one JSON object per detection per frame):

```json
{"id":"det_0001","label":"person","confidence":0.87,"box":{"x1":120.0,"y1":80.0,"x2":260.0,"y2":430.0},"frame":{"width":640,"height":480,"timestampMs":17240}}
```

Pipe to a file:

```bash
python src/prototype_detection.py -i videos/test.mp4 > test_outputs/detections.jsonl
```

Skip frames for faster runs (process every Nth frame):

```bash
python src/prototype_detection.py -i videos/test.mp4 --step 3 > test_outputs/detections.jsonl
```

Show annotated video:

```bash
python src/prototype_detection.py -i videos/test.mp4 --step 3 --show
```

## CLI Args

| Arg | Default | Description |
|-----|---------|-------------|
| `-i, --input` | (required) | Input video file |
| `--model` | `yolo11n.pt` | YOLO model path (use `best.pt` for fine-tuned) |
| `--step` | `1` | Process every Nth frame (3 = skip 2 of 3) |
| `--show` | off | Display annotated video window |
| `--display-width` | auto | Max preview width (only with `--show`) |
| `--display-height` | auto | Max preview height (only with `--show`) |

## Export model (for Flutter)

```bash
# Export base model to ONNX (recommended)
python src/export_model.py

# Export fine-tuned model to ONNX
python src/export_model.py --model best.pt

# Export with custom opset for mobile compat
python src/export_model.py --model best.pt --opset 12

# Export to TFLite (Linux/macOS only)
python src/export_model.py --model best.pt --format tflite
```

Output goes to `exports/`:
- `best.onnx` (10 MB) — fine-tuned, 10 obstacle classes
- `yolo11n.onnx` (10 MB) — base COCO, 80 classes
- `labels.txt` — class names in index order (matches the last exported model)

> **Mobile compat:** ONNX opset 12 is the default export. YOLO11 uses attention blocks (`C2fAttn`) which may not work on all mobile ONNX Runtime builds. If the Flutter team gets Reshape errors, try switching to YOLOv8n (`yolov8n.pt`) which has no attention blocks and wider ONNX Runtime compatibility.

### On-device integration (Flutter)

Use `onnxruntime_v2` package — it supports GPU acceleration on both platforms:

| Platform | Provider | Speedup |
|----------|----------|---------|
| Android  | NNAPI    | 3–7×    |
| iOS      | CoreML   | 5–15×   |

```dart
final options = OrtSessionOptions();
options.appendDefaultProviders(); // auto-selects GPU, falls back to CPU
final session = OrtSession.fromFile('best.onnx', options);
```

- **Input:** `1 × 3 × 640 × 640` (NCHW), normalized to [0, 1]
- **Output:** `1 × 84 × 8400` (base COCO) or `1 × 14 × 8400` (fine-tuned)
- **Decode:** standard YOLO output — 8400 candidates, each with box (4) + confidence (1) + class scores

> TFLite export is unavailable on Windows (ultralytics 8.4+ LiteRT format). **Not a blocker** — ONNX Runtime (`onnxruntime_v2`) covers all mobile platforms with GPU acceleration. TFLite export (via Colab or Linux/macOS) is optional if the Flutter team prefers TFLite for specific hardware backends.

## Fine-tune with Roboflow pedestrian obstacle dataset

```bash
# Prepare split (dataset lives in datasets/)
python training/prepare_roboflow_split.py

# Fine-tune YOLO11n
python training/train_yolo11_roboflow.py --model yolo11n.pt --epochs 75 --imgsz 640
```

Best checkpoint saved to `training/runs/yolo11n_roboflow_obstacles/weights/best.pt`.

Run inference with fine-tuned model:

```bash
python src/prototype_detection.py -i videos/test.mp4 --model training/runs/yolo11n_roboflow_obstacles/weights/best.pt
```

## Output JSON spec

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique detection ID (`det_NNNN`) |
| `label` | string | COCO class name |
| `confidence` | float | 0.0–1.0 |
| `box` | object | `{x1, y1, x2, y2}` in pixels |
| `frame.width` | int | Frame width |
| `frame.height` | int | Frame height |
| `frame.timestampMs` | int | Milliseconds from video start |

## Person 2 Scope Only

This lab builds the **raw detection pipeline** and exports the model for Flutter.
- Zone mapping → Person 3 (Dart)
- Distance estimation → Person 3 (Dart)
- Risk scoring / alerts → Person 3 (Dart)
