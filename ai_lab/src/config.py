YOLO_MODEL = "yolo11n.pt"
YOLO_CONFIDENCE = 0.25

RELEVANT_CLASSES = [
    0,   # person (Avoid collisions with pedestrians) [cite: 59]
    1,   # bicycle [cite: 62]
    2,   # car [cite: 60]
    3,   # motorcycle [cite: 63]
    5,   # bus 
    7,   # truck (CRITICAL addition for street crossings)
    15,  # cat
    16,  # dog [cite: 66]
    56,  # chair [cite: 64]
    9,   # traffic light (Highly useful for crosswalk awareness later)
    11,  # stop sign
]
