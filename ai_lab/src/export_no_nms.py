"""Export pruned model WITHOUT baked-in NMS.

Loads yolo11n.pt, prunes detection head to 11 classes,
loads the pruned weights, exports without NMS.

Output shape: (1, 75, 8400) = (1, nc + reg_max*4, 8400)
"""
import sys
from pathlib import Path

import torch
import torch.nn as nn

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from ultralytics import YOLO

KEEP = [0, 1, 2, 3, 5, 7, 9, 11, 15, 16, 56]
NEW_NAMES = [
    "person", "bicycle", "car", "motorcycle",
    "bus", "truck", "traffic light", "stop sign",
    "cat", "dog", "chair",
]
NUM_KEEP = len(KEEP)
EXPORTS_DIR = Path(__file__).resolve().parent.parent / "exports"
PRUNED_PT = EXPORTS_DIR / "yolo11n_pruned.pt"

def prune_head(model):
    """Prune detection head cv3 layers from 80→11 channels in-place."""
    m = model.model
    detect = m.model[-1]
    print(f"Detection head: {type(detect).__name__}, nc={detect.nc}, reg_max={detect.reg_max}")

    new_cv3 = nn.ModuleList()
    for i, seq in enumerate(detect.cv3):
        layers = list(seq)
        last_conv_idx = None
        for j in range(len(layers) - 1, -1, -1):
            if isinstance(layers[j], nn.Conv2d):
                last_conv_idx = j
                break
        if last_conv_idx is None:
            new_cv3.append(seq)
            continue

        old_conv = layers[last_conv_idx]
        in_c = old_conv.in_channels
        k = old_conv.kernel_size[0]
        s = old_conv.stride[0]
        p = old_conv.padding[0]
        new_conv = nn.Conv2d(in_c, NUM_KEEP, k, stride=s, padding=p,
                             bias=old_conv.bias is not None)
        layers[last_conv_idx] = new_conv
        new_cv3.append(nn.Sequential(*layers))

    detect.cv3 = new_cv3
    detect.nc = NUM_KEEP
    detect.no = NUM_KEEP + detect.reg_max * 4
    m.names = {i: NEW_NAMES[i] for i in range(NUM_KEEP)}

def load_pruned_weights(model):
    """Load saved pruned state dict, skipping shape mismatches."""
    state = torch.load(PRUNED_PT, map_location="cpu", weights_only=True)
    missing, unexpected = model.model.load_state_dict(state, strict=False)
    if missing:
        print(f"  Missing keys (expected): {len(missing)}")
    if unexpected:
        print(f"  Unexpected keys (expected): {len(unexpected)}")

def main():
    if not PRUNED_PT.exists():
        print(f"Error: pruned model not found at {PRUNED_PT}")
        sys.exit(1)

    print("Loading yolo11n.pt...")
    model = YOLO("yolo11n.pt")
    prune_head(model)
    load_pruned_weights(model)

    # Verify
    detect = model.model.model[-1]
    print(f"\nVerification:")
    print(f"  nc={detect.nc}")
    for i, seq in enumerate(detect.cv3):
        last = list(seq)[-1]
        print(f"  cv3[{i}] last layer: {last}  out_channels={last.out_channels}")

    out_shape = detect.no
    print(f"  Output channels: {out_shape}")

    print(f"\nExporting without NMS...")
    out = model.export(
        format="onnx",
        imgsz=640,
        opset=12,
        nms=False,
    )
    out_path = Path(out)
    dest = EXPORTS_DIR / "yolo11n_pruned_no_nms.onnx"
    import shutil
    shutil.copy2(out_path, dest)

    size_mb = dest.stat().st_size / 1024 / 1024
    print(f"\nExported: {dest} ({size_mb:.1f} MB)")
    print(f"Output: (1, {out_shape}, 8400)  [no NMS]")

if __name__ == "__main__":
    main()
