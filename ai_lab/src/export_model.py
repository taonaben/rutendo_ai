import argparse
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ultralytics import YOLO

from src.config import YOLO_MODEL


EXPORTS_DIR = Path(__file__).resolve().parent.parent / "exports"


def write_labels(labels):
    EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
    labels_path = EXPORTS_DIR / "labels.txt"
    labels_path.write_text("\n".join(labels) + "\n", encoding="utf-8")
    return labels_path


def main():
    parser = argparse.ArgumentParser(description="Export YOLO model for Flutter")
    parser.add_argument("--model", default=None, help="Model path (default: from config)")
    parser.add_argument("--imgsz", type=int, default=640, help="Input size (default: 640)")
    parser.add_argument("--opset", type=int, default=12, help="ONNX opset version (default: 12, lower for mobile compat)")
    parser.add_argument("--format", default="onnx", choices=["onnx", "tflite"],
                        help="Export format (onnx recommended — Flutter onnxruntime_v2 supports GPU on mobile)")
    parser.add_argument("--int8", action="store_true",
                        help="INT8 quantization (tflite only, Linux/macOS, smaller/faster)")
    parser.add_argument("--nms", action="store_true",
                        help="Bake NMS into ONNX graph. Output becomes (1,max_det,6): xyxy+conf+cls_id.")
    args = parser.parse_args()

    model_path = args.model or YOLO_MODEL
    model_file = Path(model_path)
    if not model_file.exists():
        print(f"Error: model not found: {model_file.resolve()}")
        sys.exit(1)

    print(f"Model: {model_file}")
    print(f"Format: {args.format}")
    print(f"Input size: {args.imgsz}x{args.imgsz}")

    EXPORTS_DIR.mkdir(parents=True, exist_ok=True)

    model = YOLO(str(model_file))
    export_kwargs = {"format": args.format, "imgsz": args.imgsz}
    if args.format == "onnx":
        export_kwargs["opset"] = args.opset
        if args.nms:
            export_kwargs["nms"] = True
            export_kwargs["conf"] = 0.25
            export_kwargs["iou"] = 0.7
    if args.format == "tflite" and args.int8:
        export_kwargs["int8"] = True

    out_path = Path(model.export(**export_kwargs))

    model_stem = model_file.stem
    suffix = "_int8" if (args.format == "tflite" and args.int8) else ""
    ext = ".tflite" if args.format == "tflite" else ".onnx"
    dest = EXPORTS_DIR / f"{model_stem}{suffix}{ext}"
    if out_path != dest:
        shutil.copy2(out_path, dest)

    class_names = model.names if hasattr(model, "names") else model.model.names
    raw_labels = [class_names[i] for i in sorted(class_names)]
    labels_path = write_labels(raw_labels)

    size_mb = dest.stat().st_size / 1024 / 1024
    print(f"\nExported: {dest} ({size_mb:.1f} MB)")
    print(f"Labels:   {labels_path}")
    print(f"Input:    {args.imgsz}x{args.imgsz}x3  (1, 3, {args.imgsz}, {args.imgsz})")
    if args.nms:
        print(f"Output:   (1, 300, 6)  [x1,y1,x2,y2,conf,cls_id]  (NMS baked-in)")
    else:
        print(f"Output:   (1, {len(raw_labels)}, 8400)  [cx,cy,w,h,class_scores...]  (raw anchors)")


if __name__ == "__main__":
    main()
