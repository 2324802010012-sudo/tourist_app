from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf
from fastapi import Body, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps, UnidentifiedImageError

from backend import database

BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "models" / "tourism_mobilenetv2.keras"
CLASS_NAMES_PATH = BASE_DIR / "models" / "class_names.json"
LOCATIONS_PATH = BASE_DIR / "config" / "locations.json"
LABELS_PATH = BASE_DIR / "config" / "labels.json"
IMG_SIZE = 224
CONFIDENCE_THRESHOLD = 0.7
MAX_UPLOAD_BYTES = 10 * 1024 * 1024

app = FastAPI(title="Tourism AI Backend", version="2.0.0-db")
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
    """Hỗ trợ cả format cũ và format mới của locations.json."""

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
        print(
            f"[WARN] Chưa có model tại {MODEL_PATH}. "
            "/predict sẽ lỗi cho đến khi bạn train xong."
        )
    else:
        model = tf.keras.models.load_model(MODEL_PATH)
        print(f"[OK] Loaded model: {MODEL_PATH}")

    if CLASS_NAMES_PATH.exists():
        class_names = load_json(CLASS_NAMES_PATH)
    else:
        labels = load_json(LABELS_PATH)
        class_names = [label_of(item) for item in labels]

    seed_locations = [normalize_location(item) for item in load_json(LOCATIONS_PATH)]
    database.init_database()
    database.seed_reference_data(
        seed_locations,
        model_path=str(MODEL_PATH),
        labels_path=str(CLASS_NAMES_PATH) if CLASS_NAMES_PATH.exists() else None,
        confidence_threshold=CONFIDENCE_THRESHOLD,
    )

    locations = [normalize_location(item) for item in database.list_locations()]
    locations_by_label = {str(item["label"]): item for item in locations}

    missing_locations = sorted(set(class_names) - set(locations_by_label))
    if missing_locations:
        print(f"[WARN] CSDL thiếu thông tin cho: {missing_locations}")
    print(f"[OK] Loaded {len(class_names)} labels, {len(locations_by_label)} locations")


def image_to_batch(content: bytes) -> np.ndarray:
    try:
        img = Image.open(BytesIO(content))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail="File gửi lên không phải ảnh hợp lệ",
        ) from exc
    img = img.resize((IMG_SIZE, IMG_SIZE))
    arr = np.asarray(img, dtype=np.float32)
    return np.expand_dims(arr, axis=0)


def prediction_item(index: int, confidence: float) -> dict[str, Any]:
    label = class_names[index]
    location = locations_by_label.get(
        label,
        {
            "id": label,
            "label": label,
            "predicted_label": label,
            "name": label,
            "location_name": label,
        },
    )
    return {
        "label": label,
        "predicted_label": label,
        "name": location.get("name") or location.get("location_name") or label,
        "location_name": location.get("location_name")
        or location.get("name")
        or label,
        "province": location.get("province", ""),
        "thumbnail_url": location.get("thumbnail_url", ""),
        "confidence": round(float(confidence), 5),
        "location": location,
    }


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "num_classes": len(class_names),
        "num_locations": len(locations_by_label),
        "labels": class_names,
        "database": database.connection_summary(),
    }


@app.get("/locations")
def get_locations() -> list[dict[str, Any]]:
    return database.list_locations()


@app.get("/locations/{location_id}")
def get_location(location_id: str) -> dict[str, Any]:
    location = database.get_location(location_id)
    if location is not None:
        return location
    raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")


@app.get("/locations/{place_code}/images")
def get_location_images(place_code: str) -> list[dict[str, Any]]:
    if database.get_location(place_code) is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")
    return database.list_place_images(place_code)


@app.get("/locations/{place_code}/videos")
def get_location_videos(place_code: str) -> list[dict[str, Any]]:
    if database.get_location(place_code) is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")
    return database.list_place_videos(place_code)


@app.get("/locations/{place_code}/advice")
def get_location_advice(place_code: str) -> dict[str, Any]:
    advice = database.get_travel_advice(place_code)
    if advice is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tư vấn du lịch")
    return advice


@app.get("/locations/{place_code}/nearby-services")
def get_nearby_services(place_code: str) -> list[dict[str, Any]]:
    if database.get_location(place_code) is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")
    return database.list_nearby_services(place_code)


@app.get("/ai-models")
def get_ai_models() -> list[dict[str, Any]]:
    return database.list_ai_models()


@app.post("/users/sync")
def sync_user(payload: dict[str, Any] = Body(...)) -> dict[str, Any]:
    firebase_uid = str(payload.get("firebase_uid") or "").strip()
    email = str(payload.get("email") or "").strip()
    if not firebase_uid or not email:
        raise HTTPException(
            status_code=400,
            detail="firebase_uid và email là bắt buộc",
        )
    return database.upsert_user(
        firebase_uid=firebase_uid,
        email=email,
        full_name=_optional_text(payload.get("full_name")),
        avatar_url=_optional_text(payload.get("avatar_url")),
        phone_number=_optional_text(payload.get("phone_number")),
    )


@app.get("/users/{firebase_uid}")
def get_user(firebase_uid: str) -> dict[str, Any]:
    user = database.get_user(firebase_uid)
    if user is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    return user


@app.get("/users/{firebase_uid}/preferences")
def get_user_preferences(firebase_uid: str) -> list[str]:
    return database.get_preferences(firebase_uid)


@app.put("/users/{firebase_uid}/preferences")
def replace_user_preferences(
    firebase_uid: str,
    payload: dict[str, Any] = Body(...),
) -> list[str]:
    preferences = payload.get("preferences") or []
    if not isinstance(preferences, list):
        raise HTTPException(status_code=400, detail="preferences phải là danh sách")
    try:
        return database.replace_preferences(
            firebase_uid,
            [str(item) for item in preferences],
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/users/{firebase_uid}/favorites")
def get_user_favorites(firebase_uid: str) -> list[str]:
    return database.list_favorite_codes(firebase_uid)


@app.get("/users/{firebase_uid}/favorites/{place_code}")
def get_user_favorite(firebase_uid: str, place_code: str) -> dict[str, bool]:
    return {"is_favorite": database.is_favorite(firebase_uid, place_code)}


@app.put("/users/{firebase_uid}/favorites/{place_code}")
def add_user_favorite(firebase_uid: str, place_code: str) -> dict[str, bool]:
    try:
        return {
            "is_favorite": database.set_favorite(
                firebase_uid,
                place_code,
                favorite=True,
            )
        }
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.delete("/users/{firebase_uid}/favorites/{place_code}")
def remove_user_favorite(firebase_uid: str, place_code: str) -> dict[str, bool]:
    try:
        return {
            "is_favorite": database.set_favorite(
                firebase_uid,
                place_code,
                favorite=False,
            )
        }
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/recognition-histories")
def create_recognition_history(
    payload: dict[str, Any] = Body(...),
) -> dict[str, Any]:
    top3 = payload.get("top3") or []
    if not isinstance(top3, list):
        raise HTTPException(status_code=400, detail="top3 phải là danh sách")
    try:
        return database.create_history(
            firebase_uid=_optional_text(payload.get("firebase_uid")),
            predicted_place_code=_optional_text(payload.get("predicted_label")),
            confidence=_optional_float(payload.get("confidence")),
            is_confident=bool(payload.get("is_confident", False)),
            recognition_status=str(payload.get("recognition_status") or "success"),
            recognized_at=_optional_text(payload.get("recognized_at")),
            image_url=_optional_text(payload.get("image_url")),
            image_hash=_optional_text(payload.get("image_hash")),
            top_candidates=[dict(item) for item in top3 if isinstance(item, dict)],
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/users/{firebase_uid}/recognition-histories")
def get_user_histories(firebase_uid: str, limit: int = 50) -> list[dict[str, Any]]:
    safe_limit = max(1, min(limit, 200))
    return database.list_histories(firebase_uid, limit=safe_limit)


@app.delete("/users/{firebase_uid}/recognition-histories")
def clear_user_histories(firebase_uid: str) -> dict[str, int]:
    return {"deleted_count": database.clear_histories(firebase_uid)}


@app.delete("/users/{firebase_uid}/recognition-histories/{place_code}")
def delete_user_histories_for_place(
    firebase_uid: str,
    place_code: str,
) -> dict[str, int]:
    return {
        "deleted_count": database.delete_histories_for_place(
            firebase_uid,
            place_code,
        )
    }


@app.post("/recognition-feedbacks")
def create_recognition_feedback(
    payload: dict[str, Any] = Body(...),
) -> dict[str, Any]:
    verdict = str(payload.get("verdict") or "").strip()
    if verdict not in {"correct", "wrong", "uncertain"}:
        raise HTTPException(
            status_code=400,
            detail="verdict phải là correct, wrong hoặc uncertain",
        )
    try:
        return database.create_feedback(
            firebase_uid=_optional_text(payload.get("firebase_uid")),
            predicted_place_code=_optional_text(payload.get("predicted_label")),
            correct_place_code=_optional_text(payload.get("corrected_label")),
            history_id=_optional_int(payload.get("history_id")),
            verdict=verdict,
            feedback_content=_optional_text(payload.get("feedback_content")),
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/predict")
async def predict(file: UploadFile = File(...)) -> dict[str, Any]:
    if model is None:
        raise HTTPException(
            status_code=503,
            detail="Model chưa được train hoặc chưa đặt vào thư mục models/",
        )
    if file.content_type and not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File gửi lên phải là ảnh")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Ảnh gửi lên đang rỗng")
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Ảnh gửi lên vượt quá 10MB")

    batch = image_to_batch(content)
    preds = model.predict(batch, verbose=0)[0]
    top_idx = np.argsort(preds)[::-1][:3]
    best_idx = int(top_idx[0])
    label = class_names[best_idx]
    confidence = float(preds[best_idx])
    location = locations_by_label.get(
        label,
        {
            "id": label,
            "label": label,
            "predicted_label": label,
            "name": label,
            "location_name": label,
        },
    )
    top_predictions = [prediction_item(int(i), float(preds[int(i)])) for i in top_idx]
    is_confident = confidence >= CONFIDENCE_THRESHOLD
    return {
        "id": location.get("id", label),
        "label": label,
        "predicted_label": label,
        "name": location.get("name") or location.get("location_name") or label,
        "location_name": location.get("location_name")
        or location.get("name")
        or label,
        "confidence": round(confidence, 5),
        "is_confident": is_confident,
        "recognized": is_confident,
        "confidence_threshold": CONFIDENCE_THRESHOLD,
        "top3": top_predictions,
        "location": location,
    }


def _optional_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _optional_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Giá trị số không hợp lệ") from exc


def _optional_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Giá trị nguyên không hợp lệ") from exc
