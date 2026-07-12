"""
Prune yolo11n.pt from 80 COCO classes to 11 relevant classes.

Keeps: person, bicycle, car, motorcycle, bus, truck,
       traffic light, stop sign, cat, dog, chair
      
COCO indices kept: 0,1,2,3,5,7,9,11,15,16,56
These are remapped to output indices 0-10.
"""
import sys
from pathlib import Path

import torch
import torch.nn as nn

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from ultralytics import YOLO
from src.export_model import main as export_main

KEEP = [0, 1, 2, 3, 5, 7, 9, 11, 15, 16, 56]
NEW_NAMES = [
    "person", "bicycle", "car", "motorcycle",
    "bus", "truck", "traffic light", "stop sign",
    "cat", "dog", "chair",
]
NUM_KEEP = len(KEEP)

EXPORTS_DIR = Path(__file__).resolve().parent.parent / "exports"


def prune_state_dict(state_dict, key_prefix="model.22"):
    """Prune the class prediction conv layers in the state dict."""

    new_sd = {}
    for k, v in state_dict.items():
        # cv3 layers: pattern like `model.22.cv3.i.conv.weight` or `model.22.cv3.i.2.weight`
        # where i is 0,1,2 and the last layer in sequential is the class conv
        if "cv3" in k:
            parts = k.split(".")
            # Find the layer index within cv3 sequential
            # pattern: model.22.cv3.0.2.weight → cv3[0] sequential, layer 2 = nn.Conv2d
            # or: model.22.cv3.0.conv.weight → cv3[0], Conv layer
            cv3_idx = int(parts[parts.index("cv3") + 1])
            layer_type = parts[-2]  # 'weight' or 'bias'
            is_bias = layer_type == "bias"

            # Only modify the last conv layer in each cv3 sequential
            # For YOLO11, cv3[i] = Sequential(Conv, Conv, Conv2d) or similar
            # The last Conv2d has out_channels = nc = 80
            # We need to identify which layer this is

            # Check if this is the classification conv (output channels = 80)
            if not is_bias and v.shape[0] == 80:
                # This is the class prediction conv layer
                new_v = v[KEEP, :, :, :].contiguous()  # (11, in_c, kH, kW)
                new_sd[k] = new_v
            elif is_bias and v.shape[0] == 80:
                new_v = v[KEEP].contiguous()
                new_sd[k] = new_v
            else:
                new_sd[k] = v
        elif "nc" in k.lower() and v.numel() == 1 and v.item() == 80:
            new_sd[k] = torch.tensor(11)
        else:
            new_sd[k] = v

    return new_sd


def main():
    model_path = Path("yolo11n.pt")
    if not model_path.exists():
        print(f"Error: {model_path} not found")
        sys.exit(1)

    print(f"Loading {model_path}...")
    model = YOLO(str(model_path))
    m = model.model

    detect = m.model[-1]
    print(f"Detection head type: {type(detect).__name__}")
    print(f"Current nc: {detect.nc}")

    # Prune cv3 (class prediction) conv layers
    new_cv3 = nn.ModuleList()
    for i, seq in enumerate(detect.cv3):
        layers = list(seq)
        # Find the last Conv2d layer (the class prediction output)
        last_conv_idx = None
        for j in range(len(layers) - 1, -1, -1):
            if isinstance(layers[j], nn.Conv2d):
                last_conv_idx = j
                break

        if last_conv_idx is None:
            print(f"Warning: no Conv2d found in cv3[{i}], skipping")
            new_cv3.append(seq)
            continue

        old_conv = layers[last_conv_idx]
        in_c = old_conv.in_channels
        k = old_conv.kernel_size[0]
        s = old_conv.stride[0]
        p = old_conv.padding[0]

        print(f"  cv3[{i}]: pruning Conv2d {old_conv.weight.shape} → ({NUM_KEEP}, {in_c}, {k}, {k})")

        new_conv = nn.Conv2d(in_c, NUM_KEEP, k, stride=s, padding=p,
                             bias=old_conv.bias is not None)

        with torch.no_grad():
            new_conv.weight.data = old_conv.weight.data[KEEP, :, :, :].clone()
            if old_conv.bias is not None:
                new_conv.bias.data = old_conv.bias.data[KEEP].clone()

        layers[last_conv_idx] = new_conv
        new_cv3.append(nn.Sequential(*layers))

    detect.cv3 = new_cv3
    detect.nc = NUM_KEEP
    detect.no = NUM_KEEP + detect.reg_max * 4

    # Update model names
    m.names = {i: NEW_NAMES[i] for i in range(NUM_KEEP)}

    # Save pruned .pt
    pruned_pt = EXPORTS_DIR / "yolo11n_pruned.pt"
    torch.save(m.state_dict(), pruned_pt)
    print(f"\nSaved pruned state dict: {pruned_pt}")

    # Save labels
    labels_path = EXPORTS_DIR / "labels_pruned.txt"
    labels_path.write_text("\n".join(NEW_NAMES) + "\n", encoding="utf-8")
    print(f"Labels:   {labels_path}")

    # Verify
    print(f"\nVerification:")
    print(f"  New nc: {detect.nc}")
    for i, seq in enumerate(detect.cv3):
        last = list(seq)[-1]
        print(f"  cv3[{i}] last layer: {last}  out_channels={last.out_channels}")

    # Now export with nms=True by calling the export script's logic
    print(f"\nExporting with nms=True...")
    model.export(format="onnx", imgsz=640, opset=12,
                 nms=True, conf=0.25, iou=0.7)

    print("\nDone. Pruned model exported successfully.")


if __name__ == "__main__":
    main()
