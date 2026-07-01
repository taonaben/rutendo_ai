import argparse
import json
import sys
from pathlib import Path

import cv2
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ultralytics import YOLO

from src.config import YOLO_MODEL, YOLO_CONFIDENCE, RELEVANT_CLASSES


COCO_NAMES = {
    0: "person", 1: "bicycle", 2: "car", 3: "motorcycle", 5: "bus",
    6: "train", 7: "truck", 9: "traffic light", 11: "stop sign",
    15: "cat", 16: "dog", 56: "chair", 67: "cell phone",
}

det_counter = 0


def process_frame(model, frame, frame_idx, fps):
    global det_counter
    results = model(frame, imgsz=640, conf=YOLO_CONFIDENCE)[0]
    h, w = frame.shape[:2]
    timestamp_ms = int(frame_idx / fps * 1000) if fps > 0 else 0
    detections = []

    for box in results.boxes:
        cls_id = int(box.cls[0])
        if cls_id not in RELEVANT_CLASSES:
            continue

        det_counter += 1
        x1, y1, x2, y2 = [round(float(v), 1) for v in box.xyxy[0]]

        detections.append({
            "id": f"det_{det_counter:04d}",
            "label": COCO_NAMES.get(cls_id, f"class_{cls_id}"),
            "confidence": round(float(box.conf[0]), 2),
            "box": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
            "frame": {"width": w, "height": h, "timestampMs": timestamp_ms},
        })

    return detections


def main():
    global det_counter
    parser = argparse.ArgumentParser(description="Rutendo AI — raw detection output")
    parser.add_argument("--input", "-i", required=True, help="Input video file")
    parser.add_argument("--model", default=YOLO_MODEL, help="YOLO model path")
    parser.add_argument("--step", type=int, default=1, help="Process every Nth frame (default: 1)")
    parser.add_argument("--show", action="store_true", help="Show annotated video window")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: input file not found: {input_path}")
        sys.exit(1)

    print(f"Loading model: {args.model}", file=sys.stderr)
    model = YOLO(args.model)

    cap = cv2.VideoCapture(str(input_path))
    if not cap.isOpened():
        print(f"Error: could not open video: {input_path}")
        sys.exit(1)

    fps = cap.get(cv2.CAP_PROP_FPS)
    frame_idx = 0
    det_counter = 0
    clean_every = 200

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            frame_idx += 1

            if (frame_idx - 1) % args.step != 0:
                continue

            detections = process_frame(model, frame, frame_idx, fps)

            for d in detections:
                print(json.dumps(d))

            if args.show:
                for d in detections:
                    b = d["box"]
                    cv2.rectangle(frame, (int(b["x1"]), int(b["y1"])),
                                  (int(b["x2"]), int(b["y2"])), (0, 255, 0), 2)
                    cv2.putText(frame, d["label"],
                                (int(b["x1"]), int(b["y1"]) - 5),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                cv2.imshow("Rutendo AI", frame)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break

            if frame_idx % clean_every == 0:
                torch.cuda.empty_cache()

    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        cv2.destroyAllWindows()

    print(f"Processed {frame_idx} frames, {det_counter} detections", file=sys.stderr)


if __name__ == "__main__":
    main()
