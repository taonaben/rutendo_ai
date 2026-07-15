import argparse
from pathlib import Path

from prepare_roboflow_split import OUTPUT_DIR, PROJECT_ROOT, create_split


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fine-tune YOLO11 on the Roboflow pedestrian obstacle dataset."
    )
    parser.add_argument("--model", default="yolo11n.pt", help="Base YOLO model or checkpoint")
    parser.add_argument("--epochs", type=int, default=75)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", default="auto", help="Batch size, integer or 'auto'")
    parser.add_argument("--device", default=None, help="Training device, e.g. 0, cpu, cuda:0")
    parser.add_argument("--name", default="yolo11n_roboflow_obstacles")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()

    create_split()
    data_yaml = OUTPUT_DIR / "data.yaml"

    if args.prepare_only:
        return

    from ultralytics import YOLO

    batch = -1 if args.batch == "auto" else int(args.batch)
    model = YOLO(args.model)

    train_kwargs = {
        "data": str(data_yaml),
        "epochs": args.epochs,
        "imgsz": args.imgsz,
        "batch": batch,
        "project": str(PROJECT_ROOT / "training" / "runs"),
        "name": args.name,
        "patience": 15,
        "plots": True,
    }
    if args.device:
        train_kwargs["device"] = args.device

    model.train(**train_kwargs)

    best = PROJECT_ROOT / "training" / "runs" / args.name / "weights" / "best.pt"
    print(f"Best checkpoint: {best}")
    print("Use it with: python src/prototype_detection.py -i <video> --model " + str(best))


if __name__ == "__main__":
    main()
