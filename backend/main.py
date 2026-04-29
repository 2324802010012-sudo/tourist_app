from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps, UnidentifiedImageError

BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "models" / "tourism_mobilenetv2.keras"
CLASS_NAMES_PATH = BASE_DIR / "models" / "class_names.json"
LOCATIONS_PATH = BASE_DIR / "config" / "locations.json"
LABELS_PATH = BASE_DIR / "config" / "labels.json"
IMG_SIZE = 224

app = FastAPI(title="Tourism AI Backend", version="1.1.0-new-labels")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model: tf.keras.Model | None = None
class_names: list[str] = []
locations_by_label: dict[str, dict[str, Any]] = {}


def load_json(path: Path) -> Any:
    if not path.exists():
        raise FileNotFoundError(f"Không thấy file: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def label_of(item: dict[str, Any]) -> str:
    value = item.get("label") or item.get("id") or item.get("predicted_label")
    if value is None or value == "":
        raise ValueError(f"Không tìm thấy label/id/predicted_label trong item: {item}")
    return str(value)


def normalize_location(item: dict[str, Any]) -> dict[str, Any]:
    """Hỗ trợ cả format cũ và format locations.json mới của bạn.

    Format mới có:
    - predicted_label
    - location_name
    - description
    - thumbnail_url

    Backend bổ sung thêm key chuẩn label/name/short_description/image_url để app dễ dùng.
    """
    loc = dict(item)
    label = str(loc.get("label") or loc.get("predicted_label") or loc.get("id"))
    name = str(loc.get("name") or loc.get("location_name") or label)
    loc.setdefault("label", label)
    loc.setdefault("predicted_label", label)
    loc.setdefault("name", name)
    loc.setdefault("location_name", name)
    loc.setdefault("short_description", loc.get("description", ""))
    loc.setdefault("image_url", loc.get("thumbnail_url", ""))
    loc.setdefault("thumbnail_url", loc.get("image_url", ""))
    return loc


@app.on_event("startup")
def startup() -> None:
    global model, class_names, locations_by_label
    if not MODEL_PATH.exists():
        print(f"[WARN] Chưa có model tại {MODEL_PATH}. /predict sẽ lỗi cho đến khi bạn train xong.")
    else:
        model = tf.keras.models.load_model(MODEL_PATH)
        print(f"[OK] Loaded model: {MODEL_PATH}")

    if CLASS_NAMES_PATH.exists():
        class_names = load_json(CLASS_NAMES_PATH)
    else:
        labels = load_json(LABELS_PATH)
        class_names = [label_of(item) for item in labels]

    locations = [normalize_location(item) for item in load_json(LOCATIONS_PATH)]
    locations_by_label = {str(item["label"]): item for item in locations}

    missing_locations = sorted(set(class_names) - set(locations_by_label))
    if missing_locations:
        print(f"[WARN] locations.json thiếu thông tin cho: {missing_locations}")
    print(f"[OK] Loaded {len(class_names)} labels, {len(locations_by_label)} locations")


def image_to_batch(content: bytes) -> np.ndarray:
    try:
        img = Image.open(BytesIO(content))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(status_code=400, detail="File gửi lên không phải ảnh hợp lệ")
    img = img.resize((IMG_SIZE, IMG_SIZE))
    arr = np.asarray(img, dtype=np.float32)
    return np.expand_dims(arr, axis=0)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "num_classes": len(class_names),
        "num_locations": len(locations_by_label),
        "labels": class_names,
    }


@app.get("/locations")
def get_locations() -> list[dict[str, Any]]:
    return list(locations_by_label.values())


@app.get("/locations/{location_id}")
def get_location(location_id: str) -> dict[str, Any]:
    for loc in locations_by_label.values():
        if str(loc.get("id")) == location_id or str(loc.get("label")) == location_id or str(loc.get("predicted_label")) == location_id:
            return loc
    raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")


@app.post("/predict")
async def predict(file: UploadFile = File(...)) -> dict[str, Any]:
    if model is None:
        raise HTTPException(status_code=503, detail="Model chưa được train hoặc chưa đặt vào thư mục models/")
    content = await file.read()
    batch = image_to_batch(content)
    preds = model.predict(batch, verbose=0)[0]
    top_idx = np.argsort(preds)[::-1][:3]
    best_idx = int(top_idx[0])
    label = class_names[best_idx]
    confidence = float(preds[best_idx])
    location = locations_by_label.get(label, {"id": label, "label": label, "predicted_label": label, "name": label, "location_name": label})
    return {
        "id": location.get("id", label),
        "label": label,
        "predicted_label": label,
        "name": location.get("name") or location.get("location_name") or label,
        "location_name": location.get("location_name") or location.get("name") or label,
        "confidence": round(confidence, 5),
        "top3": [
            {
                "label": class_names[int(i)],
                "predicted_label": class_names[int(i)],
                "name": (locations_by_label.get(class_names[int(i)], {}).get("name") or locations_by_label.get(class_names[int(i)], {}).get("location_name") or class_names[int(i)]),
                "location_name": (locations_by_label.get(class_names[int(i)], {}).get("location_name") or locations_by_label.get(class_names[int(i)], {}).get("name") or class_names[int(i)]),
                "confidence": round(float(preds[int(i)]), 5),
            }
            for i in top_idx
        ],
        "location": location,
    }
