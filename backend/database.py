from __future__ import annotations

import json
import os
import re
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Iterator

import pymysql
from pymysql.cursors import DictCursor

BASE_DIR = Path(__file__).resolve().parent.parent
BACKEND_DIR = Path(__file__).resolve().parent
SCHEMA_PATH = BACKEND_DIR / "schema.sql"
_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z0-9_]+$")


@dataclass(frozen=True)
class MySQLConfig:
    host: str
    port: int
    user: str
    password: str
    database: str


class MySQLConnection:
    def __init__(self, raw: pymysql.connections.Connection) -> None:
        self.raw = raw

    def __enter__(self) -> "MySQLConnection":
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        if exc_type is None:
            self.raw.commit()
        else:
            self.raw.rollback()
        self.raw.close()

    def close(self) -> None:
        self.raw.close()

    def execute(self, sql: str, params: Iterable[Any] | None = None):
        cursor = self.raw.cursor()
        cursor.execute(_mysqlize(sql), tuple(params or ()))
        return cursor


def utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)


def load_config() -> MySQLConfig:
    database = os.getenv("MYSQL_DATABASE", "tourist_app").strip()
    if not _IDENTIFIER_PATTERN.fullmatch(database):
        raise ValueError("MYSQL_DATABASE chỉ được chứa chữ, số và dấu gạch dưới.")

    return MySQLConfig(
        host=os.getenv("MYSQL_HOST", "127.0.0.1").strip() or "127.0.0.1",
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root").strip() or "root",
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=database,
    )


def connection_summary() -> dict[str, Any]:
    config = load_config()
    return {
        "engine": "mysql",
        "host": config.host,
        "port": config.port,
        "database": config.database,
        "user": config.user,
    }


def get_connection() -> MySQLConnection:
    config = load_config()
    raw = pymysql.connect(
        host=config.host,
        port=config.port,
        user=config.user,
        password=config.password,
        database=config.database,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
    )
    return MySQLConnection(raw)


def init_database() -> None:
    config = load_config()
    with _server_connection(config) as raw:
        with raw.cursor() as cursor:
            cursor.execute(
                f"CREATE DATABASE IF NOT EXISTS `{config.database}` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )

    statements = _split_sql_statements(SCHEMA_PATH.read_text(encoding="utf-8"))
    with get_connection() as conn:
        for statement in statements:
            conn.execute(statement)


def seed_reference_data(
    locations: list[dict[str, Any]],
    *,
    model_path: str,
    labels_path: str | None,
    confidence_threshold: float,
) -> None:
    now = utc_now()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO ai_models (
                model_name,
                model_version,
                model_path,
                labels_path,
                confidence_threshold,
                is_active,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, 1, ?)
            ON DUPLICATE KEY UPDATE
                model_path = VALUES(model_path),
                labels_path = VALUES(labels_path),
                confidence_threshold = VALUES(confidence_threshold),
                is_active = 1
            """,
            (
                "tourism_mobilenetv2",
                "1.0.0",
                model_path,
                labels_path,
                confidence_threshold,
                now,
            ),
        )

        conn.execute(
            """
            UPDATE ai_models
            SET is_active = CASE
                WHEN model_name = ? AND model_version = ? THEN 1
                ELSE 0
            END
            """,
            ("tourism_mobilenetv2", "1.0.0"),
        )

        for item in locations:
            place_code = str(item["predicted_label"])
            conn.execute(
                """
                INSERT INTO tourist_places (
                    place_code,
                    place_name,
                    province,
                    address,
                    short_description,
                    opening_hours,
                    ticket_price,
                    main_image_url,
                    status,
                    created_at,
                    updated_at,
                    map_query,
                    related_place_codes_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    place_name = VALUES(place_name),
                    province = VALUES(province),
                    address = VALUES(address),
                    short_description = VALUES(short_description),
                    opening_hours = VALUES(opening_hours),
                    ticket_price = VALUES(ticket_price),
                    main_image_url = VALUES(main_image_url),
                    status = 1,
                    updated_at = VALUES(updated_at),
                    map_query = VALUES(map_query),
                    related_place_codes_json = VALUES(related_place_codes_json)
                """,
                (
                    place_code,
                    item.get("location_name", place_code),
                    item.get("province"),
                    item.get("address"),
                    item.get("description"),
                    item.get("opening_hours"),
                    item.get("ticket_price"),
                    item.get("thumbnail_url"),
                    now,
                    now,
                    item.get("map_query"),
                    _json_dumps(item.get("related_locations", [])),
                ),
            )

            place_id = _place_id_by_code(conn, place_code)

            conn.execute("DELETE FROM place_images WHERE place_id = ?", (place_id,))
            image_urls = _unique_strings(
                [
                    item.get("thumbnail_url"),
                    *(item.get("gallery") or []),
                ]
            )
            for index, image_url in enumerate(image_urls, start=1):
                conn.execute(
                    """
                    INSERT INTO place_images (
                        place_id,
                        image_url,
                        caption,
                        sort_order,
                        created_at
                    )
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        place_id,
                        image_url,
                        item.get("location_name", place_code),
                        index,
                        now,
                    ),
                )

            conn.execute("DELETE FROM place_videos WHERE place_id = ?", (place_id,))
            video_url = item.get("video_url")
            if video_url:
                conn.execute(
                    """
                    INSERT INTO place_videos (
                        place_id,
                        video_title,
                        video_url,
                        is_primary,
                        status,
                        created_at
                    )
                    VALUES (?, ?, ?, 1, 1, ?)
                    """,
                    (
                        place_id,
                        f"Giới thiệu {item.get('location_name', place_code)}",
                        video_url,
                        now,
                    ),
                )

            conn.execute(
                """
                INSERT INTO travel_advices (
                    place_id,
                    highlight,
                    best_time_to_visit,
                    estimated_cost,
                    suggested_itinerary,
                    travel_notes,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    highlight = VALUES(highlight),
                    best_time_to_visit = VALUES(best_time_to_visit),
                    estimated_cost = VALUES(estimated_cost),
                    suggested_itinerary = VALUES(suggested_itinerary),
                    travel_notes = VALUES(travel_notes),
                    updated_at = VALUES(updated_at)
                """,
                (
                    place_id,
                    _json_dumps(item.get("highlights", [])),
                    item.get("best_time"),
                    item.get("estimated_cost"),
                    item.get("suggested_route"),
                    _json_dumps(item.get("travel_tips", [])),
                    now,
                    now,
                ),
            )


def list_locations() -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT *
            FROM tourist_places
            WHERE status = 1
            ORDER BY place_id
            """
        ).fetchall()
        return [_serialize_place(conn, row) for row in rows]


def get_location(identifier: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT *
            FROM tourist_places
            WHERE place_code = ?
               OR CAST(place_id AS CHAR) = ?
            LIMIT 1
            """,
            (identifier, identifier),
        ).fetchone()
        return None if row is None else _serialize_place(conn, row)


def list_place_images(place_code: str) -> list[dict[str, Any]]:
    with get_connection() as conn:
        place_id = _maybe_place_id_by_code(conn, place_code)
        if place_id is None:
            return []
        rows = conn.execute(
            """
            SELECT image_id, image_url, caption, sort_order, created_at
            FROM place_images
            WHERE place_id = ?
            ORDER BY COALESCE(sort_order, 999999), image_id
            """,
            (place_id,),
        ).fetchall()
        return [dict(row) for row in rows]


def list_place_videos(place_code: str) -> list[dict[str, Any]]:
    with get_connection() as conn:
        place_id = _maybe_place_id_by_code(conn, place_code)
        if place_id is None:
            return []
        rows = conn.execute(
            """
            SELECT video_id, video_title, video_url, duration, is_primary, status, created_at
            FROM place_videos
            WHERE place_id = ?
            ORDER BY is_primary DESC, video_id
            """,
            (place_id,),
        ).fetchall()
        return [dict(row) for row in rows]


def get_travel_advice(place_code: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        place_id = _maybe_place_id_by_code(conn, place_code)
        if place_id is None:
            return None
        row = conn.execute(
            """
            SELECT *
            FROM travel_advices
            WHERE place_id = ?
            """,
            (place_id,),
        ).fetchone()
        if row is None:
            return None
        item = dict(row)
        item["highlight"] = _json_loads_list(item.get("highlight"))
        item["travel_notes"] = _json_loads_list(item.get("travel_notes"))
        return item


def list_nearby_services(place_code: str) -> list[dict[str, Any]]:
    with get_connection() as conn:
        place_id = _maybe_place_id_by_code(conn, place_code)
        if place_id is None:
            return []
        rows = conn.execute(
            """
            SELECT *
            FROM nearby_services
            WHERE place_id = ?
            ORDER BY rating DESC, service_name
            """,
            (place_id,),
        ).fetchall()
        return [dict(row) for row in rows]


def list_ai_models() -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT *
            FROM ai_models
            ORDER BY is_active DESC, created_at DESC, model_id DESC
            """
        ).fetchall()
        return [dict(row) for row in rows]


def active_model_id() -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT model_id
            FROM ai_models
            WHERE is_active = 1
            ORDER BY created_at DESC, model_id DESC
            LIMIT 1
            """
        ).fetchone()
        if row is None:
            raise RuntimeError("Chưa có model AI đang hoạt động trong CSDL.")
        return int(row["model_id"])


def upsert_user(
    *,
    firebase_uid: str,
    email: str,
    full_name: str | None = None,
    avatar_url: str | None = None,
    phone_number: str | None = None,
) -> dict[str, Any]:
    now = utc_now()
    with get_connection() as conn:
        existing = conn.execute(
            """
            SELECT user_id
            FROM users
            WHERE firebase_uid = ?
            """,
            (firebase_uid,),
        ).fetchone()

        if existing is None:
            conn.execute(
                """
                INSERT INTO users (
                    firebase_uid,
                    email,
                    full_name,
                    avatar_url,
                    phone_number,
                    status,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, 1, ?, ?)
                """,
                (
                    firebase_uid,
                    email,
                    full_name,
                    avatar_url,
                    phone_number,
                    now,
                    now,
                ),
            )
        else:
            conn.execute(
                """
                UPDATE users
                SET email = ?,
                    full_name = COALESCE(?, full_name),
                    avatar_url = COALESCE(?, avatar_url),
                    phone_number = COALESCE(?, phone_number),
                    status = 1,
                    updated_at = ?
                WHERE firebase_uid = ?
                """,
                (
                    email,
                    full_name,
                    avatar_url,
                    phone_number,
                    now,
                    firebase_uid,
                ),
            )

        row = conn.execute(
            """
            SELECT *
            FROM users
            WHERE firebase_uid = ?
            """,
            (firebase_uid,),
        ).fetchone()
        assert row is not None
        return dict(row)


def get_user(firebase_uid: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT *
            FROM users
            WHERE firebase_uid = ?
            """,
            (firebase_uid,),
        ).fetchone()
        return None if row is None else dict(row)


def get_preferences(firebase_uid: str) -> list[str]:
    with get_connection() as conn:
        user_id = _maybe_user_id_by_uid(conn, firebase_uid)
        if user_id is None:
            return []
        rows = conn.execute(
            """
            SELECT preference_value
            FROM user_preferences
            WHERE user_id = ?
            ORDER BY preference_id
            """,
            (user_id,),
        ).fetchall()
        return [
            str(row["preference_value"])
            for row in rows
            if row["preference_value"] is not None
        ]


def replace_preferences(firebase_uid: str, preferences: Iterable[str]) -> list[str]:
    now = utc_now()
    values = _unique_strings(preferences)
    with get_connection() as conn:
        user_id = _require_user_id_by_uid(conn, firebase_uid)
        conn.execute("DELETE FROM user_preferences WHERE user_id = ?", (user_id,))
        for value in values:
            conn.execute(
                """
                INSERT INTO user_preferences (
                    user_id,
                    preference_type,
                    preference_value,
                    created_at
                )
                VALUES (?, ?, ?, ?)
                """,
                (user_id, "travel_interest", value, now),
            )
    return values


def list_favorite_codes(firebase_uid: str) -> list[str]:
    with get_connection() as conn:
        user_id = _maybe_user_id_by_uid(conn, firebase_uid)
        if user_id is None:
            return []
        rows = conn.execute(
            """
            SELECT tp.place_code
            FROM favorite_places fp
            INNER JOIN tourist_places tp ON tp.place_id = fp.place_id
            WHERE fp.user_id = ?
            ORDER BY fp.created_at DESC, fp.favorite_id DESC
            """,
            (user_id,),
        ).fetchall()
        return [str(row["place_code"]) for row in rows]


def set_favorite(firebase_uid: str, place_code: str, *, favorite: bool) -> bool:
    now = utc_now()
    with get_connection() as conn:
        user_id = _require_user_id_by_uid(conn, firebase_uid)
        place_id = _place_id_by_code(conn, place_code)
        if favorite:
            conn.execute(
                """
                INSERT IGNORE INTO favorite_places (
                    user_id,
                    place_id,
                    created_at
                )
                VALUES (?, ?, ?)
                """,
                (user_id, place_id, now),
            )
        else:
            conn.execute(
                """
                DELETE FROM favorite_places
                WHERE user_id = ? AND place_id = ?
                """,
                (user_id, place_id),
            )
        row = conn.execute(
            """
            SELECT 1
            FROM favorite_places
            WHERE user_id = ? AND place_id = ?
            LIMIT 1
            """,
            (user_id, place_id),
        ).fetchone()
        return row is not None


def is_favorite(firebase_uid: str, place_code: str) -> bool:
    with get_connection() as conn:
        user_id = _maybe_user_id_by_uid(conn, firebase_uid)
        place_id = _maybe_place_id_by_code(conn, place_code)
        if user_id is None or place_id is None:
            return False
        row = conn.execute(
            """
            SELECT 1
            FROM favorite_places
            WHERE user_id = ? AND place_id = ?
            LIMIT 1
            """,
            (user_id, place_id),
        ).fetchone()
        return row is not None


def create_history(
    *,
    firebase_uid: str | None,
    predicted_place_code: str | None,
    confidence: float | None,
    is_confident: bool,
    recognition_status: str,
    recognized_at: str | None = None,
    image_url: str | None = None,
    image_hash: str | None = None,
    top_candidates: Iterable[dict[str, Any]] = (),
) -> dict[str, Any]:
    now = _coerce_datetime(recognized_at) if recognized_at else utc_now()
    with get_connection() as conn:
        user_id = (
            None
            if firebase_uid is None
            else _maybe_user_id_by_uid(conn, firebase_uid)
        )
        predicted_place_id = (
            None
            if not predicted_place_code
            else _maybe_place_id_by_code(conn, predicted_place_code)
        )
        model_id = _active_model_id_in_conn(conn)
        cursor = conn.execute(
            """
            INSERT INTO recognition_histories (
                user_id,
                model_id,
                predicted_place_id,
                image_url,
                image_hash,
                confidence,
                is_confident,
                recognition_status,
                recognized_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                model_id,
                predicted_place_id,
                image_url,
                image_hash,
                confidence,
                int(is_confident),
                recognition_status,
                now,
            ),
        )
        history_id = int(cursor.lastrowid)
        _replace_candidates(conn, history_id, top_candidates)
        return get_history_by_id(history_id, conn=conn)


def get_history_by_id(
    history_id: int,
    *,
    conn: MySQLConnection | None = None,
) -> dict[str, Any]:
    owns_connection = conn is None
    if conn is None:
        conn = get_connection()
    try:
        row = conn.execute(
            """
            SELECT rh.*
            FROM recognition_histories rh
            WHERE rh.history_id = ?
            """,
            (history_id,),
        ).fetchone()
        if row is None:
            raise LookupError(f"Không tìm thấy lịch sử {history_id}.")
        return _serialize_history(conn, row)
    finally:
        if owns_connection:
            conn.close()


def list_histories(firebase_uid: str, *, limit: int = 50) -> list[dict[str, Any]]:
    with get_connection() as conn:
        user_id = _maybe_user_id_by_uid(conn, firebase_uid)
        if user_id is None:
            return []
        rows = conn.execute(
            """
            SELECT rh.*
            FROM recognition_histories rh
            WHERE rh.user_id = ?
              AND rh.predicted_place_id IS NOT NULL
            ORDER BY rh.recognized_at DESC, rh.history_id DESC
            LIMIT ?
            """,
            (user_id, limit),
        ).fetchall()
        return [_serialize_history(conn, row) for row in rows]


def delete_histories_for_place(firebase_uid: str, place_code: str) -> int:
    with get_connection() as conn:
        user_id = _maybe_user_id_by_uid(conn, firebase_uid)
        place_id = _maybe_place_id_by_code(conn, place_code)
        if user_id is None or place_id is None:
            return 0
        cursor = conn.execute(
            """
            DELETE FROM recognition_histories
            WHERE user_id = ? AND predicted_place_id = ?
            """,
            (user_id, place_id),
        )
        return cursor.rowcount


def clear_histories(firebase_uid: str) -> int:
    with get_connection() as conn:
        user_id = _maybe_user_id_by_uid(conn, firebase_uid)
        if user_id is None:
            return 0
        cursor = conn.execute(
            """
            DELETE FROM recognition_histories
            WHERE user_id = ?
            """,
            (user_id,),
        )
        return cursor.rowcount


def create_feedback(
    *,
    firebase_uid: str | None,
    predicted_place_code: str | None,
    correct_place_code: str | None,
    history_id: int | None,
    verdict: str,
    feedback_content: str | None,
) -> dict[str, Any]:
    now = utc_now()
    with get_connection() as conn:
        user_id = (
            None
            if firebase_uid is None
            else _maybe_user_id_by_uid(conn, firebase_uid)
        )
        predicted_place_id = (
            None
            if not predicted_place_code
            else _maybe_place_id_by_code(conn, predicted_place_code)
        )
        correct_place_id = (
            None
            if not correct_place_code
            else _maybe_place_id_by_code(conn, correct_place_code)
        )
        if verdict == "correct" and correct_place_id is None:
            correct_place_id = predicted_place_id

        if history_id is None:
            model_id = _active_model_id_in_conn(conn)
            cursor = conn.execute(
                """
                INSERT INTO recognition_histories (
                    user_id,
                    model_id,
                    predicted_place_id,
                    confidence,
                    is_confident,
                    recognition_status,
                    recognized_at
                )
                VALUES (?, ?, ?, NULL, 0, ?, ?)
                """,
                (
                    user_id,
                    model_id,
                    predicted_place_id,
                    "manual_detail",
                    now,
                ),
            )
            history_id = int(cursor.lastrowid)

        cursor = conn.execute(
            """
            INSERT INTO recognition_feedbacks (
                history_id,
                user_id,
                predicted_place_id,
                correct_place_id,
                is_correct,
                feedback_content,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                history_id,
                user_id,
                predicted_place_id,
                correct_place_id,
                int(verdict == "correct"),
                feedback_content,
                now,
            ),
        )
        feedback_id = int(cursor.lastrowid)
        row = conn.execute(
            """
            SELECT *
            FROM recognition_feedbacks
            WHERE feedback_id = ?
            """,
            (feedback_id,),
        ).fetchone()
        assert row is not None
        return dict(row)


def _serialize_place(conn: MySQLConnection, row: dict[str, Any]) -> dict[str, Any]:
    advice = conn.execute(
        """
        SELECT *
        FROM travel_advices
        WHERE place_id = ?
        """,
        (row["place_id"],),
    ).fetchone()
    primary_video = conn.execute(
        """
        SELECT video_url
        FROM place_videos
        WHERE place_id = ? AND status = 1
        ORDER BY is_primary DESC, video_id
        LIMIT 1
        """,
        (row["place_id"],),
    ).fetchone()
    image_rows = conn.execute(
        """
        SELECT image_url
        FROM place_images
        WHERE place_id = ?
        ORDER BY COALESCE(sort_order, 999999), image_id
        """,
        (row["place_id"],),
    ).fetchall()

    image_urls = [str(image["image_url"]) for image in image_rows]
    main_image = row["main_image_url"] or (image_urls[0] if image_urls else "")
    gallery = [image_url for image_url in image_urls if image_url != main_image]

    return {
        "id": int(row["place_id"]),
        "place_id": int(row["place_id"]),
        "predicted_label": row["place_code"],
        "label": row["place_code"],
        "place_code": row["place_code"],
        "location_name": row["place_name"],
        "name": row["place_name"],
        "province": row["province"] or "",
        "address": row["address"] or "",
        "description": row["short_description"] or "",
        "history_description": row["history_description"] or "",
        "opening_hours": row["opening_hours"] or "",
        "ticket_price": row["ticket_price"] or "",
        "best_time": "" if advice is None else advice["best_time_to_visit"] or "",
        "estimated_cost": "" if advice is None else advice["estimated_cost"] or "",
        "suggested_route": ""
        if advice is None
        else advice["suggested_itinerary"] or "",
        "travel_tips": []
        if advice is None
        else _json_loads_list(advice["travel_notes"]),
        "map_query": row["map_query"] or "",
        "highlights": []
        if advice is None
        else _json_loads_list(advice["highlight"]),
        "video_url": "" if primary_video is None else primary_video["video_url"],
        "thumbnail_url": main_image,
        "gallery": gallery,
        "related_locations": _json_loads_list(row["related_place_codes_json"]),
    }


def _serialize_history(
    conn: MySQLConnection,
    row: dict[str, Any],
) -> dict[str, Any]:
    place_row = None
    if row["predicted_place_id"] is not None:
        place_row = conn.execute(
            """
            SELECT *
            FROM tourist_places
            WHERE place_id = ?
            """,
            (row["predicted_place_id"],),
        ).fetchone()

    place_payload = {} if place_row is None else _serialize_place(conn, place_row)
    candidates = conn.execute(
        """
        SELECT rc.rank_no, rc.confidence, tp.place_code
        FROM recognition_candidates rc
        LEFT JOIN tourist_places tp ON tp.place_id = rc.place_id
        WHERE rc.history_id = ?
        ORDER BY rc.rank_no
        """,
        (row["history_id"],),
    ).fetchall()
    candidate_payload = []
    for candidate in candidates:
        place_code = candidate["place_code"]
        if place_code is None:
            continue
        candidate_place_row = conn.execute(
            """
            SELECT *
            FROM tourist_places
            WHERE place_code = ?
            """,
            (str(place_code),),
        ).fetchone()
        if candidate_place_row is None:
            continue
        candidate_place = _serialize_place(conn, candidate_place_row)
        candidate_payload.append(
            {
                "predicted_label": candidate_place["predicted_label"],
                "location_name": candidate_place["location_name"],
                "province": candidate_place["province"],
                "thumbnail_url": candidate_place["thumbnail_url"],
                "confidence": float(candidate["confidence"]),
            }
        )

    return {
        **place_payload,
        "history_id": int(row["history_id"]),
        "confidence": float(row["confidence"] or 0),
        "is_confident": bool(row["is_confident"]),
        "recognition_status": row["recognition_status"],
        "recognized_at": row["recognized_at"],
        "top3": candidate_payload,
    }


def _replace_candidates(
    conn: MySQLConnection,
    history_id: int,
    top_candidates: Iterable[dict[str, Any]],
) -> None:
    now = utc_now()
    conn.execute(
        "DELETE FROM recognition_candidates WHERE history_id = ?",
        (history_id,),
    )
    for rank_no, candidate in enumerate(top_candidates, start=1):
        place_code = str(
            candidate.get("predicted_label")
            or candidate.get("label")
            or ""
        ).strip()
        if not place_code:
            continue
        place_id = _maybe_place_id_by_code(conn, place_code)
        confidence = float(candidate.get("confidence") or 0)
        conn.execute(
            """
            INSERT INTO recognition_candidates (
                history_id,
                place_id,
                rank_no,
                confidence,
                created_at
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (history_id, place_id, rank_no, confidence, now),
        )


def _place_id_by_code(conn: MySQLConnection, place_code: str) -> int:
    place_id = _maybe_place_id_by_code(conn, place_code)
    if place_id is None:
        raise LookupError(f"Không tìm thấy địa điểm {place_code}.")
    return place_id


def _maybe_place_id_by_code(
    conn: MySQLConnection,
    place_code: str,
) -> int | None:
    row = conn.execute(
        """
        SELECT place_id
        FROM tourist_places
        WHERE place_code = ?
        """,
        (place_code,),
    ).fetchone()
    return None if row is None else int(row["place_id"])


def _require_user_id_by_uid(conn: MySQLConnection, firebase_uid: str) -> int:
    user_id = _maybe_user_id_by_uid(conn, firebase_uid)
    if user_id is None:
        raise LookupError(f"Không tìm thấy người dùng {firebase_uid}.")
    return user_id


def _maybe_user_id_by_uid(
    conn: MySQLConnection,
    firebase_uid: str,
) -> int | None:
    row = conn.execute(
        """
        SELECT user_id
        FROM users
        WHERE firebase_uid = ?
        """,
        (firebase_uid,),
    ).fetchone()
    return None if row is None else int(row["user_id"])


def _active_model_id_in_conn(conn: MySQLConnection) -> int:
    row = conn.execute(
        """
        SELECT model_id
        FROM ai_models
        WHERE is_active = 1
        ORDER BY created_at DESC, model_id DESC
        LIMIT 1
        """
    ).fetchone()
    if row is None:
        raise RuntimeError("Chưa có model AI đang hoạt động trong CSDL.")
    return int(row["model_id"])


@contextmanager
def _server_connection(config: MySQLConfig) -> Iterator[pymysql.connections.Connection]:
    raw = pymysql.connect(
        host=config.host,
        port=config.port,
        user=config.user,
        password=config.password,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=True,
    )
    try:
        yield raw
    finally:
        raw.close()


def _mysqlize(sql: str) -> str:
    return sql.replace("?", "%s")


def _split_sql_statements(sql: str) -> list[str]:
    return [statement.strip() for statement in sql.split(";") if statement.strip()]


def _coerce_datetime(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed.replace(microsecond=0)


def _json_dumps(value: Any) -> str:
    return json.dumps(value or [], ensure_ascii=False)


def _json_loads_list(value: Any) -> list[str]:
    if value in (None, ""):
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    try:
        decoded = json.loads(str(value))
    except json.JSONDecodeError:
        return [str(value)]
    if isinstance(decoded, list):
        return [str(item) for item in decoded]
    return [str(decoded)]


def _unique_strings(values: Iterable[Any]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value is None:
            continue
        text = str(value).strip()
        if not text or text in seen:
            continue
        seen.add(text)
        result.append(text)
    return result
