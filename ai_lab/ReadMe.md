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

## Fine-tune with the Roboflow pedestrian obstacle dataset

The Roboflow export in `datasets/Pedestrian Obstacle Detection.v6-for-validation.yolov11`
contains YOLO labels for:

`animal`, `barrier`, `bike`, `crosswalk`, `hazard-sign`, `person`, `pole`, `stairs`, `stall`, `vehicle`

The current download is a validation-only export, so first create deterministic
train/validation/test split files from the labeled images:

```bash
python training/prepare_roboflow_split.py
```

Fine-tune YOLO11n:

```bash
python training/train_yolo11_roboflow.py --model yolo11n.pt --epochs 75 --imgsz 640
```

For an interactive notebook workflow, use:

```text
notebooks/train_yolo11_roboflow.ipynb
```

The best checkpoint will be saved under:

```text
training/runs/yolo11n_roboflow_obstacles/weights/best.pt
```

Run detection with the fine-tuned model:

```bash
python src/prototype_detection.py -i videos/test.mp4 --model training/runs/yolo11n_roboflow_obstacles/weights/best.pt
```

## CLI Args

| Arg | Default | Description |
|-----|---------|-------------|
| `-i, --input` | (required) | Input video file |
| `--model` | `yolov8n.pt` | YOLO model path |
| `--step` | `1` | Process every Nth frame (3 = skip 2 of 3) |
| `--show` | off | Display annotated video window |

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
