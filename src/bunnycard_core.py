#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import csv
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


VIDEO_EXTS = {".mp4", ".mov", ".mxf", ".m4v", ".mkv", ".avi", ".webm"}
PHOTO_EXTS = {".jpg", ".jpeg", ".dng", ".arw", ".cr2", ".cr3", ".nef", ".raf", ".heic", ".png", ".tif", ".tiff"}
DELETE_SIDECAR_EXTS = {".lrf", ".xml"}
AUDIO_SIDECAR_EXTS = {".aac", ".wav"}
SKIP_FILE_EXTS = {".dmg", ".iso", ".pkg"}
SKIP_DIRS = {
    ".Spotlight-V100",
    ".TemporaryItems",
    ".Trashes",
    ".fseventsd",
    "$RECYCLE.BIN",
    "System Volume Information",
    "FOUND.000",
}

CATEGORY_LABELS = {
    "Aerial": {"zh": "航拍", "en": "Aerial"},
    "Campus_Daily": {"zh": "校园日常", "en": "Campus_Daily"},
    "Classroom_Talk": {"zh": "教室闲谈", "en": "Classroom_Talk"},
    "City": {"zh": "城市", "en": "City"},
    "Events": {"zh": "活动", "en": "Events"},
    "Graduation": {"zh": "毕业典礼", "en": "Graduation"},
    "People": {"zh": "人物", "en": "People"},
    "RoboCup": {"zh": "RoboCup", "en": "RoboCup"},
    "Robotics_Setup": {"zh": "机器人调试", "en": "Robotics_Setup"},
    "Sports_Field": {"zh": "运动场", "en": "Sports_Field"},
    "Travel_Hometown": {"zh": "旅途与家乡", "en": "Travel_Hometown"},
    "Handheld_Material": {"zh": "手持素材", "en": "Handheld_Material"},
    "Unsorted": {"zh": "未分类", "en": "Unsorted"},
    "Photo": {"zh": "照片", "en": "Photo"},
}

TAG_LABELS = {
    "robocup": {"zh": "机器人比赛", "en": "robocup"},
    "robotics": {"zh": "机器人调试", "en": "robotics"},
    "drone_aerial": {"zh": "航拍", "en": "drone_aerial"},
    "graduation": {"zh": "毕业典礼", "en": "graduation"},
    "sports_field": {"zh": "运动场", "en": "sports_field"},
    "campus_daily": {"zh": "校园日常", "en": "campus_daily"},
    "classroom_talk": {"zh": "教室闲谈", "en": "classroom_talk"},
    "city": {"zh": "城市", "en": "city"},
    "event": {"zh": "活动", "en": "event"},
    "people": {"zh": "人物", "en": "people"},
    "travel_hometown": {"zh": "旅途家乡", "en": "travel_hometown"},
    "handheld": {"zh": "手持", "en": "handheld"},
    "material": {"zh": "素材", "en": "material"},
    "photo": {"zh": "照片", "en": "photo"},
}

TAG_ALIASES = {
    "机器人比赛": "robocup",
    "机器人竞赛": "robocup",
    "比赛": "event",
    "机器人调试": "robotics",
    "机器人": "robotics",
    "航拍": "drone_aerial",
    "无人机": "drone_aerial",
    "毕业典礼": "graduation",
    "毕业": "graduation",
    "运动场": "sports_field",
    "操场": "sports_field",
    "校园日常": "campus_daily",
    "校园": "campus_daily",
    "教室闲谈": "classroom_talk",
    "教室": "classroom_talk",
    "城市": "city",
    "活动": "event",
    "人物": "people",
    "人像": "people",
    "旅途家乡": "travel_hometown",
    "旅行": "travel_hometown",
    "家乡": "travel_hometown",
    "手持": "handheld",
    "手持素材": "handheld",
    "素材": "material",
    "照片": "photo",
    "photo": "photo",
    "photos": "photo",
    "aerial": "drone_aerial",
    "drone": "drone_aerial",
    "drone_aerial": "drone_aerial",
    "robocup": "robocup",
    "robot": "robotics",
    "robotics": "robotics",
    "graduation": "graduation",
    "sports": "sports_field",
    "sports_field": "sports_field",
    "campus": "campus_daily",
    "campus_daily": "campus_daily",
    "classroom": "classroom_talk",
    "classroom_talk": "classroom_talk",
    "city": "city",
    "event": "event",
    "events": "event",
    "people": "people",
    "person": "people",
    "travel": "travel_hometown",
    "travel_hometown": "travel_hometown",
    "handheld": "handheld",
    "material": "material",
}

@dataclass
class ProjectTag:
    key: str
    zh: str
    en: str


KIND_LABELS = {
    "video": {"zh": "视频", "en": "Video"},
    "photo": {"zh": "照片", "en": "Photo"},
    "audio_sidecar": {"zh": "音频伴随", "en": "Audio Sidecar"},
    "delete_sidecar": {"zh": "可删除附属文件", "en": "Disposable Sidecar"},
    "other": {"zh": "其他", "en": "Other"},
}

STATUS_LABELS = {
    "dry_run": {"zh": "计划复制", "en": "Will Copy"},
    "verified": {"zh": "已复制并校验", "en": "Copied and Verified"},
    "already_verified": {"zh": "目标已存在且一致", "en": "Already Verified"},
    "hash_mismatch": {"zh": "哈希不一致", "en": "Hash Mismatch"},
    "orphan_audio_sidecar": {"zh": "未找到对应视频", "en": "No Matching Video"},
    "deleted": {"zh": "已删除", "en": "Deleted"},
    "failed": {"zh": "失败", "en": "Failed"},
}

THUMBNAIL_EXTS = VIDEO_EXTS | PHOTO_EXTS
CAMERA_DIR_HINTS = {"DCIM", "PRIVATE", "M4ROOT", "AVCHD", "BPAV", "XDROOT", "CONTENTS", "CLIP"}
SYSTEM_VOLUME_NAMES = {"Macintosh HD", "com.apple.TimeMachine.localsnapshots", "Preboot", "Recovery", "VM", "Update"}
TOOL_DIRS = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]


@dataclass
class MediaFile:
    path: Path
    rel_path: Path
    kind: str
    size: int
    captured_at: dt.datetime
    device: str
    profile: str
    encoder: str


def eprint(message: str) -> None:
    try:
        print(message, file=sys.stderr, flush=True)
    except BrokenPipeError:
        raise SystemExit(0)


def emit_jsonl(payload: dict) -> None:
    try:
        print(json.dumps(payload, ensure_ascii=False), flush=True)
    except BrokenPipeError:
        raise SystemExit(0)


def tool_path(name: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    for directory in TOOL_DIRS:
        candidate = Path(directory) / name
        if candidate.exists() and os.access(candidate, os.X_OK):
            return candidate.as_posix()
    return ""


def is_hidden_sidecar(path: Path) -> bool:
    return path.name.startswith("._") or path.name == ".DS_Store"


def iter_files(root: Path) -> Iterable[Path]:
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.lower().endswith(".app")]
        for name in files:
            p = Path(current) / name
            if is_hidden_sidecar(p) or p.suffix.lower() in SKIP_FILE_EXTS:
                continue
            yield p


def media_kind(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in VIDEO_EXTS:
        return "video"
    if ext in PHOTO_EXTS:
        return "photo"
    if ext in AUDIO_SIDECAR_EXTS:
        return "audio_sidecar"
    if ext in DELETE_SIDECAR_EXTS:
        return "delete_sidecar"
    return "other"


def fast_volume_profile(volume: Path) -> dict:
    hints: list[str] = []
    counts = {"video": 0, "photo": 0, "audio_sidecar": 0, "delete_sidecar": 0, "other": 0}
    bytes_by_kind = {k: 0 for k in counts}
    scanned = 0
    try:
        entries = list(volume.iterdir())
    except OSError:
        entries = []
    top_names = {p.name for p in entries}
    root_hint_count = 0
    for hint in sorted(CAMERA_DIR_HINTS):
        if hint in top_names:
            hints.append(hint)
            root_hint_count += 1
    for path in iter_files(volume):
        scanned += 1
        if scanned > 1500:
            break
        kind = media_kind(path)
        try:
            size = path.stat().st_size
        except OSError:
            size = 0
        counts[kind] = counts.get(kind, 0) + 1
        bytes_by_kind[kind] = bytes_by_kind.get(kind, 0) + size
        parts = set(path.parts)
        hints.extend(sorted(CAMERA_DIR_HINTS.intersection(parts)))
    hints = sorted(set(hints))
    score = root_hint_count * 80 + max(0, len(hints) - root_hint_count) * 8 + min(counts["video"] + counts["photo"], 80)
    try:
        disk = shutil.disk_usage(volume)
        disk_total = disk.total
        disk_free = disk.free
    except OSError:
        disk_total = 0
        disk_free = 0
    return {
        "path": volume.as_posix(),
        "name": volume.name,
        "is_system": volume.name in SYSTEM_VOLUME_NAMES or volume.as_posix() == "/",
        "camera_score": score,
        "has_camera_structure": bool(hints),
        "camera_hints": hints,
        "counts": counts,
        "gib_by_kind": {k: size_gib(v) for k, v in bytes_by_kind.items()},
        "disk_total_bytes": disk_total,
        "disk_free_bytes": disk_free,
    }


def parse_capture_time(path: Path) -> dt.datetime:
    name = path.name
    match = re.search(r"DJI_(\d{8})(\d{6})", name)
    if match:
        return dt.datetime.strptime(match.group(1) + match.group(2), "%Y%m%d%H%M%S")
    match = re.search(r"(20\d{2})[-_]?(\d{2})[-_]?(\d{2})[-_ ]?(\d{2})?(\d{2})?(\d{2})?", name)
    if match:
        year, month, day = int(match.group(1)), int(match.group(2)), int(match.group(3))
        hour = int(match.group(4) or 0)
        minute = int(match.group(5) or 0)
        second = int(match.group(6) or 0)
        try:
            return dt.datetime(year, month, day, hour, minute, second)
        except ValueError:
            pass
    return dt.datetime.fromtimestamp(path.stat().st_mtime)


def ffprobe_tags(path: Path) -> dict[str, str]:
    if path.suffix.lower() not in VIDEO_EXTS:
        return {}
    ffprobe = tool_path("ffprobe")
    if not ffprobe:
        return {}
    try:
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "quiet",
                "-show_entries",
                "format_tags=encoder,make,model,creation_time",
                "-of",
                "json",
                path.as_posix(),
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {}
    if result.returncode != 0 or not result.stdout.strip():
        return {}
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}
    tags = data.get("format", {}).get("tags", {})
    return {str(k).lower(): str(v) for k, v in tags.items()}


def device_from_text(path: Path, encoder: str = "") -> str:
    name = path.name.lower()
    joined = path.as_posix().lower() + " " + encoder.lower()
    if "osmopocket4" in joined or "osmo pocket 4" in joined:
        return "OsmoPocket4"
    if "osmopocket3" in joined or "osmo pocket 3" in joined:
        return "OsmoPocket3"
    if "osmo" in joined and "pocket" in joined:
        return "OsmoPocket"
    if "osmo" in joined and "action" in joined:
        return "OsmoAction"
    if re.search(r"\bmavic\b|\bmini\s?[234]\b|air\s?3|avata|phantom|inspire", joined):
        return "DJIDrone"
    if name.startswith("dji_"):
        return "DJI"
    if name.startswith("img_"):
        return "iPhone"
    if re.match(r"c\d{4}", name):
        return "A7M4"
    if "action" in joined:
        return "Action4"
    return "Camera"


def profile_marker(path: Path) -> str:
    text = path.as_posix().lower()
    stem = path.stem.lower()
    if "slog3" in text or "s-log3" in text:
        return "slog3"
    if "slog2" in text or "s-log2" in text:
        return "slog2"
    if "d-log" in text or "dlog" in text or stem.endswith("_d"):
        return "dlogm"
    return ""


def scalar_text(value: object, fallback: str = "") -> str:
    if value is None:
        return fallback
    if isinstance(value, str):
        return value
    if isinstance(value, (int, float, bool)):
        return str(value)
    if isinstance(value, list):
        parts = [scalar_text(item, "") for item in value]
        return "_".join(part for part in parts if part) or fallback
    if isinstance(value, dict):
        for key in ("tag", "label", "name", "category", "value"):
            if key in value:
                text = scalar_text(value.get(key), "")
                if text:
                    return text
        return "_".join(scalar_text(item, "") for item in value.values() if scalar_text(item, "")) or fallback
    return fallback


def slug(value: object, fallback: str = "material") -> str:
    value = scalar_text(value, fallback).strip().lower()
    value = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value or fallback


def ascii_slug(value: object, fallback: str = "material") -> str:
    value = scalar_text(value, fallback).strip().lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value or fallback


def label(table: dict[str, dict[str, str]], key: str, language: str) -> str:
    normalized = "zh" if language == "zh" else "en"
    return table.get(key, {}).get(normalized) or table.get(key, {}).get("en") or key


def tag_for_filename(tag: str, language: str, project_tags: list[ProjectTag] | None = None) -> str:
    return slug(project_tag_label(project_tags, tag, language), "素材" if language == "zh" else "material")


def category_for_folder(category: str, language: str) -> str:
    return label(CATEGORY_LABELS, category, language)


def canonical_tag(value: object, fallback: str = "material", allow_free: bool = True) -> str:
    raw = scalar_text(value, fallback).strip().lower()
    alias_key = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", "_", raw)
    alias_key = re.sub(r"_+", "_", alias_key).strip("_")
    if alias_key in TAG_ALIASES:
        return TAG_ALIASES[alias_key]
    tag = ascii_slug(raw, "")
    if tag in TAG_ALIASES:
        return TAG_ALIASES[tag]
    if tag in TAG_LABELS:
        return tag
    for alias, canonical in TAG_ALIASES.items():
        if re.search(r"[\u4e00-\u9fff]", alias) and alias in alias_key:
            return canonical
    return tag if allow_free and tag else fallback


def parse_project_tags(value: str | list[str] | list[dict] | None) -> list[ProjectTag]:
    if not value:
        return []
    parsed_value: object = value
    if isinstance(value, str):
        stripped = value.strip()
        if stripped.startswith("[") or stripped.startswith("{"):
            try:
                parsed_value = json.loads(stripped)
            except json.JSONDecodeError:
                parsed_value = value
    if isinstance(parsed_value, dict):
        raw_items = [parsed_value]
    elif isinstance(parsed_value, list):
        raw_items = parsed_value
    else:
        raw_items = re.split(r"[,，;；\n]+", str(parsed_value))
    seen: set[str] = set()
    tags: list[ProjectTag] = []
    for item in raw_items:
        if isinstance(item, ProjectTag):
            key = item.key
            zh = item.zh
            en = item.en
        elif isinstance(item, dict):
            key = canonical_tag(item.get("key") or item.get("tag") or item.get("en") or item.get("zh") or "", "", True)
            zh = scalar_text(item.get("zh"), "") or label(TAG_LABELS, key, "zh")
            en = scalar_text(item.get("en"), "") or label(TAG_LABELS, key, "en")
        else:
            key = canonical_tag(item, "", True)
            zh = label(TAG_LABELS, key, "zh")
            en = label(TAG_LABELS, key, "en")
        if not key or key in seen:
            continue
        seen.add(key)
        tags.append(ProjectTag(key=key, zh=zh, en=en))
    return tags


def project_tag_keys(tags: list[ProjectTag] | None) -> list[str]:
    return [tag.key for tag in tags or [] if tag.key]


def project_tag_label(tags: list[ProjectTag] | None, key: str, language: str) -> str:
    for tag in tags or []:
        if tag.key == key:
            return tag.zh if language == "zh" else tag.en
    return label(TAG_LABELS, key, language)


def project_tag_label_map(tags: list[ProjectTag] | None) -> dict[str, dict[str, str]]:
    return {tag.key: {"zh": tag.zh, "en": tag.en} for tag in tags or []}


def normalize_model_tag(value: object, fallback: str, detail: str = "concise", allowed_tags: list[ProjectTag] | None = None) -> str:
    allowed = parse_project_tags(allowed_tags)
    raw = scalar_text(value, fallback).strip().lower()
    raw_ascii = ascii_slug(raw, "")
    placeholder_bits = {"2_4", "english", "snake_case", "words", "word"}
    fallback_tag = canonical_tag(fallback, "material", True)
    if any(bit in raw_ascii for bit in placeholder_bits):
        tag = fallback_tag
    else:
        tag = canonical_tag(value, fallback_tag, detail == "rich")
    allowed_keys = project_tag_keys(allowed)
    if allowed_keys:
        if tag in allowed_keys:
            return tag
        for allowed_tag in allowed:
            en_ascii = ascii_slug(allowed_tag.en, "")
            zh_alias = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", "_", allowed_tag.zh.lower())
            zh_alias = re.sub(r"_+", "_", zh_alias).strip("_")
            if allowed_tag.key in raw_ascii or (en_ascii and en_ascii in raw_ascii) or (zh_alias and zh_alias in raw):
                return allowed_tag.key
        if fallback_tag in allowed_keys:
            return fallback_tag
        if "material" in allowed_keys:
            return "material"
        return allowed_keys[0]
    if detail == "rich" and re.fullmatch(r"[a-z0-9]+(?:_[a-z0-9]+)*", tag):
        return tag
    if tag in TAG_LABELS:
        return tag
    return fallback_tag


def render_name_template(
    template: str,
    media: MediaFile,
    tag: str,
    language: str,
    kind_word: str,
    project_tags: list[ProjectTag] | None = None,
) -> str:
    values = {
        "device": media.device,
        "date": media.captured_at.strftime("%Y-%m-%d"),
        "time": media.captured_at.strftime("%H%M"),
        "datetime": media.captured_at.strftime("%Y-%m-%d_%H%M"),
        "profile": media.profile,
        "tag": tag_for_filename(tag, language, project_tags),
        "kind": kind_word,
        "original": media.path.stem,
    }
    rendered = template
    for key, value in values.items():
        rendered = rendered.replace("{" + key + "}", value or "")
    fallback = "素材" if language == "zh" else "material"
    return slug(rendered, fallback)


def sha256_file(path: Path, chunk_size: int = 4 * 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def candidate_paths(path: Path) -> Iterable[Path]:
    yield path
    for i in range(1, 10000):
        yield path.with_name(f"{path.stem}_{i:02d}{path.suffix}")


def unique_path(path: Path, reserved: set[Path] | None = None) -> Path:
    reserved = set() if reserved is None else reserved
    for candidate in candidate_paths(path):
        if candidate not in reserved and not candidate.exists():
            return candidate
    raise RuntimeError(f"Could not find unique path for {path}")


def collect_encoder_hints(paths: list[Path]) -> tuple[dict[str, str], dict[Path, str]]:
    stem_hints: dict[str, str] = {}
    dir_hints: dict[Path, str] = {}
    for path in paths:
        if media_kind(path) != "video":
            continue
        tags = ffprobe_tags(path)
        encoder = tags.get("encoder", "")
        if not encoder:
            continue
        stem_hints[pair_key(path)] = encoder
        if path.parent not in dir_hints:
            dir_hints[path.parent] = encoder
    return stem_hints, dir_hints


def scan_media(source: Path) -> list[MediaFile]:
    items: list[MediaFile] = []
    paths = list(iter_files(source))
    stem_hints, dir_hints = collect_encoder_hints(paths)
    for path in paths:
        try:
            st = path.stat()
        except OSError as exc:
            eprint(f"WARN cannot stat {path}: {exc}")
            continue
        kind = media_kind(path)
        encoder = stem_hints.get(pair_key(path), "") or dir_hints.get(path.parent, "")
        items.append(
            MediaFile(
                path=path,
                rel_path=path.relative_to(source),
                kind=kind,
                size=st.st_size,
                captured_at=parse_capture_time(path),
                device=device_from_text(path, encoder),
                profile=profile_marker(path),
                encoder=encoder,
            )
        )
    return items


def rule_classify(media: MediaFile) -> tuple[str, str]:
    text = media.path.as_posix().lower()
    if "campus" in text or "校园" in text:
        return "Campus_Daily", "campus_daily"
    if "classroom" in text or "教室" in text or "闲谈" in text:
        return "Classroom_Talk", "classroom_talk"
    if re.search(r"rcj|rcka|robocup|robo[_ -]?cup", text):
        return "RoboCup", "robocup"
    if "robot" in text:
        return "Robotics_Setup", "robotics"
    if media.device == "DJIDrone" or re.search(r"航拍|drone|aerial|mavic|avata|phantom|inspire", text):
        return "Aerial", "drone_aerial"
    if media.device.lower().startswith("osmo") or media.device in {"DJI", "Action4"}:
        return "Handheld_Material", "handheld"
    if "graduation" in text or "毕业" in text:
        return "Graduation", "graduation"
    if "sports" in text or "field" in text or "运动场" in text or "操场" in text:
        return "Sports_Field", "sports_field"
    return "Unsorted", "material"


def sample_video_frame(video: Path, output: Path) -> bool:
    ffmpeg = tool_path("ffmpeg")
    if not ffmpeg:
        return False
    cmd = [
        ffmpeg,
        "-y",
        "-v",
        "error",
        "-ss",
        "2",
        "-i",
        video.as_posix(),
        "-frames:v",
        "1",
        "-vf",
        "scale=768:-1",
        output.as_posix(),
    ]
    try:
        return subprocess.run(cmd, timeout=30).returncode == 0 and output.exists() and output.stat().st_size > 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def make_thumbnail(media: MediaFile, audit_dir: Path) -> str:
    if media.path.suffix.lower() not in THUMBNAIL_EXTS:
        return ""
    safe_name = hashlib.sha1(media.path.as_posix().encode("utf-8")).hexdigest()[:16]
    output = audit_dir / "thumbs" / f"{safe_name}.jpg"
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and output.stat().st_size > 0:
        return output.as_posix()
    if media.kind == "video":
        ok = sample_video_frame(media.path, output)
        return output.as_posix() if ok else ""
    sips_cmd = [
        "sips",
        "-s",
        "format",
        "jpeg",
        "-Z",
        "720",
        media.path.as_posix(),
        "--out",
        output.as_posix(),
    ]
    try:
        sips = subprocess.run(sips_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        sips = subprocess.CompletedProcess(sips_cmd, 1)
    if sips.returncode == 0 and output.exists() and output.stat().st_size > 0:
        return output.as_posix()
    ffmpeg = tool_path("ffmpeg")
    if not ffmpeg:
        return ""
    ffmpeg_cmd = [
        ffmpeg,
        "-y",
        "-v",
        "error",
        "-i",
        media.path.as_posix(),
        "-frames:v",
        "1",
        "-vf",
        "scale=720:-1",
        output.as_posix(),
    ]
    try:
        ffmpeg = subprocess.run(ffmpeg_cmd, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return output.as_posix() if ffmpeg.returncode == 0 and output.exists() and output.stat().st_size > 0 else ""


def ollama_classify(
    media: MediaFile,
    model: str,
    audit_dir: Path,
    detail: str = "concise",
    project_tags: list[ProjectTag] | None = None,
) -> tuple[str, str, str, str]:
    frame = audit_dir / "frames" / f"{media.path.stem}.jpg"
    frame.parent.mkdir(parents=True, exist_ok=True)
    if media.kind != "video" or not sample_video_frame(media.path, frame):
        category, tag = rule_classify(media)
        return category, tag, "rule_no_frame", ""
    image_b64 = base64.b64encode(frame.read_bytes()).decode("ascii")
    category_prompt = (
        '["Aerial","Campus_Daily","Classroom_Talk","City","Events","Graduation",'
        '"Handheld_Material","People","RoboCup","Robotics_Setup","Sports_Field",'
        '"Travel_Hometown","Unsorted"]'
    )
    allowed_tags = parse_project_tags(project_tags)
    allowed_tag_keys = project_tag_keys(allowed_tags)
    tag_prompt = json.dumps(allowed_tag_keys, ensure_ascii=False) if allowed_tag_keys else ""
    if detail == "rich":
        prompt = (
            "Classify this frame for a media library. Return compact JSON only with keys "
            f'"category" one of {category_prompt}, '
            + (f'"tag" one of {tag_prompt}, ' if allowed_tag_keys else '"tag" as 2-4 specific English snake_case words about visible content, ')
            + '"description" as a short Chinese phrase under 32 characters. '
            "The tag value must be ASCII English snake_case only, never Chinese. "
            "Use Aerial only for actual drone/aerial viewpoint, not because "
            "the file comes from DJI or Osmo handheld cameras."
        )
    else:
        concise_tags = allowed_tag_keys or [
            "robocup",
            "robotics",
            "drone_aerial",
            "graduation",
            "sports_field",
            "campus_daily",
            "classroom_talk",
            "city",
            "event",
            "people",
            "travel_hometown",
            "handheld",
            "material",
        ]
        prompt = (
            "Classify this frame for a media library. Return compact JSON only: "
            f'{{"category": one of {category_prompt},'
            f'"tag": one of {json.dumps(concise_tags, ensure_ascii=False)}}}. '
            "The tag value must be ASCII English snake_case only, never Chinese. "
            "Use Aerial only for actual drone/aerial viewpoint, "
            "not merely because the file comes from DJI or Osmo handheld cameras."
        )
    payload = {
        "model": model,
        "prompt": prompt,
        "images": [image_b64],
        "stream": False,
        "options": {"temperature": 0.1},
    }
    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        text = body.get("response", "")
        match = re.search(r"\{.*\}", text, re.S)
        parsed = json.loads(match.group(0) if match else text)
        if not isinstance(parsed, dict):
            raise ValueError("ollama_json_not_object")
        rule_category, rule_tag = rule_classify(media)
        category = scalar_text(parsed.get("category"), "Unsorted")
        if category not in CATEGORY_LABELS:
            category = rule_category
        tag = normalize_model_tag(parsed.get("tag"), rule_tag, detail, allowed_tags)
        description = scalar_text(parsed.get("description"), "")
        return category, tag, "ollama", description[:80]
    except urllib.error.HTTPError as exc:
        category, tag = rule_classify(media)
        if exc.code == 404:
            return category, tag, f"rule_ollama_model_not_found:{model}", ""
        return category, tag, f"rule_ollama_http_{exc.code}:{exc.reason}", ""
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError, KeyError, TypeError, ValueError, AttributeError) as exc:
        category, tag = rule_classify(media)
        return category, tag, f"rule_ollama_failed:{exc}", ""


def project_part(project: str, language: str) -> str:
    fallback = "项目" if language == "zh" else "project"
    return slug(project, fallback)


def target_for_video(
    media: MediaFile,
    video_library: Path,
    category: str,
    tag: str,
    language: str,
    layout: str,
    project: str,
    name_template: str = "",
    project_tags: list[ProjectTag] | None = None,
) -> Path:
    captured = media.captured_at
    month = captured.strftime("%Y-%m")
    if name_template.strip():
        stem = render_name_template(name_template, media, tag, language, "素材" if language == "zh" else "material", project_tags)
    else:
        date_part = captured.strftime("%Y-%m-%d_%H%M")
        pieces = [media.device, date_part]
        if media.profile:
            pieces.append(media.profile)
        pieces.extend([tag_for_filename(tag, language, project_tags), "素材" if language == "zh" else "material"])
        stem = "_".join(pieces)
    filename = stem + media.path.suffix.lower()
    if layout == "project_tag":
        tag_folder = tag_for_filename(tag, language, project_tags)
        if project.strip():
            return video_library / project_part(project, language) / tag_folder / month / filename
        return video_library / tag_folder / month / filename
    return video_library / month / category_for_folder(category, language) / filename


def target_for_photo(
    media: MediaFile,
    photo_library: Path,
    language: str,
    layout: str,
    project: str,
    name_template: str = "",
    project_tags: list[ProjectTag] | None = None,
) -> Path:
    captured = media.captured_at
    day = captured.strftime("%Y-%m-%d")
    year = captured.strftime("%Y")
    if name_template.strip():
        stem = render_name_template(name_template, media, "photo", language, "照片" if language == "zh" else "photo", project_tags)
    else:
        date_part = captured.strftime("%Y-%m-%d_%H%M")
        suffix = "照片" if language == "zh" else slug(media.path.stem)
        stem = f"{media.device}_{date_part}_{slug(suffix)}"
    filename = stem + media.path.suffix.lower()
    if layout == "project_tag":
        photo_folder = label(CATEGORY_LABELS, "Photo", language)
        if project.strip():
            return photo_library / project_part(project, language) / photo_folder / day / filename
        return photo_library / photo_folder / day / filename
    return photo_library / year / day / filename


def pair_key(path: Path) -> str:
    return path.with_suffix("").as_posix()


def copy_verified(src: Path, dst: Path, dry_run: bool, reserved: set[Path] | None = None) -> tuple[str, str, str, Path]:
    reserved = set() if reserved is None else reserved
    if dry_run:
        for target in candidate_paths(dst):
            if target in reserved:
                continue
            if target.exists():
                if target.stat().st_size == src.stat().st_size:
                    src_hash = sha256_file(src)
                    dst_hash = sha256_file(target)
                    if src_hash == dst_hash:
                        reserved.add(target)
                        return "already_verified", src_hash, dst_hash, target
                continue
            reserved.add(target)
            return "dry_run", "", "", target
        raise RuntimeError(f"Could not find safe destination for {dst}")
    src_hash = sha256_file(src)
    for target in candidate_paths(dst):
        if target.exists():
            if target.stat().st_size == src.stat().st_size:
                dst_hash = sha256_file(target)
                if src_hash == dst_hash:
                    return "already_verified", src_hash, dst_hash, target
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, target)
        dst_hash = sha256_file(target)
        if src_hash == dst_hash:
            return "verified", src_hash, dst_hash, target
        return "hash_mismatch", src_hash, dst_hash, target
    raise RuntimeError(f"Could not find safe destination for {dst}")


def write_csv(path: Path, rows: list[dict], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if fieldnames is None:
        fieldnames = list(rows[0].keys()) if rows else ["message"]
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def normalize_language(value: str) -> str:
    return "zh" if value.lower() in {"zh", "cn", "chinese", "中文"} else "en"


def size_gib(size_bytes: int) -> float:
    return round(size_bytes / 1024**3, 3)


def enrich_copy_row(row: dict, language: str, project_tags: list[ProjectTag] | None = None) -> dict:
    target = Path(row["target_path"]) if row.get("target_path") else None
    source = Path(row["source_path"])
    enriched = dict(row)
    enriched["source_name"] = source.name
    enriched["target_folder"] = target.parent.as_posix() if target else ""
    enriched["target_name"] = target.name if target else ""
    enriched["size_gib"] = size_gib(int(row.get("size_bytes") or 0))
    enriched["kind_label"] = label(KIND_LABELS, row.get("kind", ""), language)
    enriched["category_label"] = label(CATEGORY_LABELS, row.get("category", ""), language)
    enriched["tag_label"] = project_tag_label(project_tags, row.get("tag", ""), language)
    enriched["status_label"] = label(STATUS_LABELS, row.get("copy_status", ""), language)
    return enriched


def import_summary(audit_dir: Path, dry_run: bool, rows: list[dict], audio_rows: list[dict], delete_rows: list[dict], sidecar_rows: list[dict]) -> dict:
    return {
        "audit_dir": audit_dir.as_posix(),
        "dry_run": dry_run,
        "copied_or_verified": sum(1 for r in rows if r["copy_status"] in {"verified", "already_verified", "dry_run"}),
        "photos": sum(1 for r in rows if r["kind"] == "photo"),
        "videos": sum(1 for r in rows if r["kind"] == "video"),
        "audio_sidecars": len(audio_rows),
        "deleted_sources": sum(1 for r in delete_rows if r["delete_status"] == "deleted"),
        "deleted_lrf_xml": sum(1 for r in sidecar_rows if r["delete_status"] == "deleted"),
    }


def backup_libraries(value: list[str] | str | None) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value] if value else []
    return [item for item in value if item]


def read_skip_source_list(path_value: str) -> set[str]:
    if not path_value:
        return set()
    path = Path(path_value).expanduser()
    try:
        return {line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()}
    except OSError:
        return set()


def read_resume_row_list(path_value: str) -> tuple[set[str], dict[str, Path]]:
    if not path_value:
        return set(), {}
    path = Path(path_value).expanduser()
    skipped_sources: set[str] = set()
    video_targets: dict[str, Path] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return skipped_sources, video_targets
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            skipped_sources.add(line)
            continue
        source_path = str(payload.get("source_path") or "")
        target_path = str(payload.get("target_path") or "")
        kind = str(payload.get("kind") or "")
        if source_path:
            skipped_sources.add(source_path)
        if source_path and target_path and kind == "video":
            video_targets[pair_key(Path(source_path))] = Path(target_path)
    return skipped_sources, video_targets


def backup_originals(
    items: list[MediaFile],
    backup_root: Path,
    dry_run: bool,
    on_row: Callable[[dict], None] | None = None,
) -> tuple[list[dict], set[str]]:
    rows: list[dict] = []
    verified_sources: set[str] = set()
    reserved: set[Path] = set()
    candidates = [i for i in items if i.kind in {"video", "photo", "audio_sidecar"}]
    for index, item in enumerate(candidates, 1):
        target = backup_root / item.rel_path
        status, src_hash, dst_hash, final_target = copy_verified(item.path, target, dry_run, reserved)
        if status in {"verified", "already_verified", "dry_run"}:
            verified_sources.add(item.path.as_posix())
        rows.append(
            {
                "source_path": item.path.as_posix(),
                "relative_path": item.rel_path.as_posix(),
                "target_path": final_target.as_posix(),
                "backup_root": backup_root.as_posix(),
                "kind": item.kind,
                "size_bytes": item.size,
                "copy_status": status,
                "source_sha256": src_hash,
                "target_sha256": dst_hash,
            }
        )
        if on_row:
            on_row(rows[-1])
        eprint(f"[backup {index}/{len(candidates)}] {status} {item.rel_path} -> {final_target}")
    return rows, verified_sources


def plan_import(
    items: list[MediaFile],
    video_library: Path,
    photo_library: Path,
    audit_dir: Path,
    use_ollama: bool,
    ollama_model: str,
    language: str,
    dry_run: bool,
    thumbnails: bool = False,
    thumbnail_limit: int = 0,
    layout: str = "month_category",
    project: str = "",
    name_template: str = "",
    ollama_detail: str = "concise",
    on_row: Callable[[dict, int, int], None] | None = None,
    resume_video_targets: dict[str, Path] | None = None,
    project_tags: str | list[ProjectTag] | None = None,
) -> tuple[list[dict], list[dict]]:
    project_tags = parse_project_tags(project_tags)
    video_targets: dict[str, Path] = dict(resume_video_targets or {})
    planned_targets: set[Path] = set()
    rows: list[dict] = []
    copy_candidates = [i for i in items if i.kind in {"video", "photo"}]
    for index, item in enumerate(copy_candidates, 1):
        if item.kind == "video":
            if use_ollama:
                category, tag, classifier, description = ollama_classify(item, ollama_model, audit_dir, ollama_detail, project_tags)
            else:
                category, tag = rule_classify(item)
                classifier = "rule"
                description = ""
            target = target_for_video(item, video_library, category, tag, language, layout, project, name_template, project_tags)
        else:
            category, tag, classifier = "Photo", "photo", "rule"
            description = ""
            target = target_for_photo(item, photo_library, language, layout, project, name_template, project_tags)
        status, src_hash, dst_hash, final_target = copy_verified(item.path, target, dry_run, planned_targets)
        if item.kind == "video":
            video_targets[pair_key(item.path)] = final_target
        eprint(f"[{index}/{len(copy_candidates)}] {status} {item.rel_path} -> {final_target}")
        row = enrich_copy_row(
            {
                "source_path": item.path.as_posix(),
                "relative_path": item.rel_path.as_posix(),
                "kind": item.kind,
                "target_path": final_target.as_posix(),
                "size_bytes": item.size,
                "captured_at": item.captured_at.isoformat(timespec="seconds"),
                "device": item.device,
                "profile": item.profile,
                "category": category,
                "tag": tag,
                "classifier": classifier,
                "description": description,
                "thumbnail_path": make_thumbnail(item, audit_dir) if thumbnails and (thumbnail_limit <= 0 or index <= thumbnail_limit) else "",
                "copy_status": status,
                "source_sha256": src_hash,
                "target_sha256": dst_hash,
                "error": "",
            },
            language,
            project_tags,
        )
        rows.append(row)
        if on_row:
            on_row(row, index, len(copy_candidates))

    audio_rows: list[dict] = []
    audio_items = [i for i in items if i.kind == "audio_sidecar"]
    for item in audio_items:
        video_target = video_targets.get(pair_key(item.path))
        if not video_target:
            raw_row = {
                "source_path": item.path.as_posix(),
                "relative_path": item.rel_path.as_posix(),
                "kind": "audio_sidecar",
                "target_path": "",
                "size_bytes": item.size,
                "copy_status": "orphan_audio_sidecar",
                "source_sha256": "",
                "target_sha256": "",
                "error": "",
            }
        else:
            wanted_target = video_target.with_suffix(item.path.suffix.lower())
            status, src_hash, dst_hash, final_target = copy_verified(item.path, wanted_target, dry_run, planned_targets)
            raw_row = {
                "source_path": item.path.as_posix(),
                "relative_path": item.rel_path.as_posix(),
                "kind": "audio_sidecar",
                "target_path": final_target.as_posix(),
                "size_bytes": item.size,
                "copy_status": status,
                "source_sha256": src_hash,
                "target_sha256": dst_hash,
                "error": "",
            }
        audio_row = enrich_copy_row(raw_row, language, project_tags)
        audio_rows.append(audio_row)
        if on_row:
            on_row(audio_row, len(copy_candidates) + len(audio_rows), len(copy_candidates) + len(audio_items))
        eprint(f"[audio] {raw_row['copy_status']} {item.rel_path}")
    return rows, audio_rows


def command_scan(args: argparse.Namespace) -> int:
    source = Path(args.source).expanduser().resolve()
    items = scan_media(source)
    counts: dict[str, int] = {}
    bytes_by_kind: dict[str, int] = {}
    for item in items:
        counts[item.kind] = counts.get(item.kind, 0) + 1
        bytes_by_kind[item.kind] = bytes_by_kind.get(item.kind, 0) + item.size
    result = {
        "source": source.as_posix(),
        "files": len(items),
        "counts": counts,
        "gib_by_kind": {k: round(v / 1024**3, 3) for k, v in bytes_by_kind.items()},
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def command_volumes(args: argparse.Namespace) -> int:
    root = Path("/Volumes")
    volumes: list[dict] = []
    for volume in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if volume.name in SYSTEM_VOLUME_NAMES or volume.name.startswith("."):
            continue
        if volume.is_symlink() and volume.resolve().as_posix() == "/":
            continue
        if not volume.is_dir():
            continue
        profile = fast_volume_profile(volume)
        if args.camera_only and not profile.get("has_camera_structure"):
            continue
        volumes.append(profile)
    volumes.sort(key=lambda v: (v["camera_score"], v["name"]), reverse=True)
    print(json.dumps({"volumes": volumes}, ensure_ascii=False))
    return 0


def command_ollama_models(args: argparse.Namespace) -> int:
    req = urllib.request.Request("http://127.0.0.1:11434/api/tags")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"available": False, "models": [], "vision_models": [], "error": repr(exc)}, ensure_ascii=False))
        return 0
    models = body.get("models", [])
    names = [m.get("name", "") for m in models if m.get("name")]
    vision_names = []
    for model in models:
        caps = set(model.get("capabilities", []))
        families = set(model.get("details", {}).get("families", []) or [])
        name = model.get("name", "")
        text = " ".join([name, *caps, *families]).lower()
        if "vision" in text or "llava" in text or "moondream" in text or "minicpm-v" in text:
            vision_names.append(name)
    print(json.dumps({"available": True, "models": names, "vision_models": vision_names, "error": ""}, ensure_ascii=False))
    return 0


def command_import_card(args: argparse.Namespace) -> int:
    source = Path(args.source).expanduser().resolve()
    video_library = Path(args.video_library).expanduser()
    photo_library = Path(args.photo_library).expanduser()
    audit_root = Path(args.audit_root).expanduser()
    language = normalize_language(args.language)
    run_id = dt.datetime.now().strftime("bunnycard_%Y%m%d_%H%M%S_") + source.name
    audit_dir = audit_root / run_id
    audit_dir.mkdir(parents=True, exist_ok=True)

    items = scan_media(source)
    write_csv(
        audit_dir / "scan_manifest.csv",
        [
            {
                "path": i.path.as_posix(),
                "relative_path": i.rel_path.as_posix(),
                "kind": i.kind,
                "size_bytes": i.size,
                "captured_at": i.captured_at.isoformat(timespec="seconds"),
                "device": i.device,
                "profile": i.profile,
            }
            for i in items
        ],
    )

    media_total = sum(1 for item in items if item.kind in {"video", "photo", "audio_sidecar"})
    backup_total = media_total * len(backup_libraries(args.backup_library))
    sidecar_total = sum(1 for item in items if item.kind == "delete_sidecar") if args.delete_sidecars and not args.dry_run else 0
    if args.stream:
        emit_jsonl(
            {
                "event": "import_scan",
                "audit_dir": audit_dir.as_posix(),
                "media_total": media_total,
                "backup_total": backup_total,
                "sidecar_total": sidecar_total,
                "total": media_total + backup_total + sidecar_total,
            }
        )

    def on_import_row(row: dict, index: int, total: int) -> None:
        if args.stream:
            emit_jsonl({"event": "import_row", "phase": "copy", "index": index, "total": total, "row": row})

    rows, audio_rows = plan_import(
        items,
        video_library,
        photo_library,
        audit_dir,
        args.use_ollama,
        args.ollama_model,
        language,
        args.dry_run,
        False,
        0,
        args.layout,
        args.project,
        args.name_template,
        args.ollama_detail,
        on_import_row if args.stream else None,
        project_tags=args.project_tags,
    )

    write_csv(audit_dir / "copy_log.csv", rows)
    write_csv(audit_dir / "audio_sidecar_copy_log.csv", audio_rows)

    backup_rows: list[dict] = []
    backup_verified_sources: set[str] | None = None
    backup_roots: list[str] = []
    backup_index = 0
    for backup_library in backup_libraries(args.backup_library):
        backup_root = Path(backup_library).expanduser() / source.name
        backup_roots.append(backup_root.as_posix())

        def on_backup_row(row: dict) -> None:
            nonlocal backup_index
            backup_index += 1
            if args.stream:
                emit_jsonl({"event": "import_row", "phase": "backup", "index": backup_index, "total": backup_total, "row": row})

        rows_for_root, verified_for_root = backup_originals(items, backup_root, args.dry_run, on_backup_row if args.stream else None)
        backup_rows.extend(rows_for_root)
        if backup_verified_sources is None:
            backup_verified_sources = set(verified_for_root)
        else:
            backup_verified_sources.intersection_update(verified_for_root)
    write_csv(audit_dir / "backup_copy_log.csv", backup_rows)

    delete_rows: list[dict] = []
    if args.delete_source and not args.dry_run:
        verified_sources = {r["source_path"] for r in rows if r["copy_status"] in {"verified", "already_verified"}}
        verified_sources.update(r["source_path"] for r in audio_rows if r["copy_status"] in {"verified", "already_verified"})
        if backup_verified_sources is not None:
            verified_sources.intersection_update(backup_verified_sources)
        for source_path in verified_sources:
            p = Path(source_path)
            status, err = "deleted", ""
            try:
                p.unlink()
            except Exception as exc:  # noqa: BLE001
                status, err = "failed", repr(exc)
            row = {"source_path": source_path, "delete_status": status, "delete_error": err}
            delete_rows.append(row)
            if args.stream:
                emit_jsonl({"event": "import_row", "phase": "delete_source", "index": len(delete_rows), "total": len(verified_sources), "row": row})
    write_csv(audit_dir / "source_delete_log.csv", delete_rows, ["source_path", "delete_status", "delete_error"])

    sidecar_rows: list[dict] = []
    if args.delete_sidecars and not args.dry_run:
        for item in items:
            if item.kind != "delete_sidecar":
                continue
            status, err = "deleted", ""
            try:
                item.path.unlink()
            except Exception as exc:  # noqa: BLE001
                status, err = "failed", repr(exc)
            row = {
                "source_path": item.path.as_posix(),
                "relative_path": item.rel_path.as_posix(),
                "size_bytes": item.size,
                "delete_status": status,
                "delete_error": err,
            }
            sidecar_rows.append(row)
            if args.stream:
                emit_jsonl({"event": "import_row", "phase": "delete_sidecar", "index": len(sidecar_rows), "total": sidecar_total, "row": row})
    write_csv(audit_dir / "sidecar_delete_log.csv", sidecar_rows, ["source_path", "relative_path", "size_bytes", "delete_status", "delete_error"])

    summary = import_summary(audit_dir, args.dry_run, rows, audio_rows, delete_rows, sidecar_rows)
    summary["backup_files"] = len(backup_rows)
    summary["backup_roots"] = backup_roots
    summary["backup_root"] = backup_roots[0] if backup_roots else ""
    (audit_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.stream:
        emit_jsonl({"event": "import_summary", "summary": summary})
    else:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def command_plan_card(args: argparse.Namespace) -> int:
    source = Path(args.source).expanduser().resolve()
    video_library = Path(args.video_library).expanduser()
    photo_library = Path(args.photo_library).expanduser()
    audit_root = Path(args.audit_root).expanduser()
    language = normalize_language(args.language)
    audit_dir = audit_root / (dt.datetime.now().strftime("bunnycard_plan_%Y%m%d_%H%M%S_") + source.name)
    audit_dir.mkdir(parents=True, exist_ok=True)
    items = scan_media(source)
    skip_sources, resume_video_targets = read_resume_row_list(args.skip_source_list)
    plan_items = [item for item in items if item.path.as_posix() not in skip_sources]

    if args.stream:
        emit_jsonl(
            {
                "event": "scan",
                "audit_dir": audit_dir.as_posix(),
                "total_files": len(items),
                "copy_candidates": sum(1 for item in plan_items if item.kind in {"video", "photo"}),
                "audio_sidecars": sum(1 for item in plan_items if item.kind == "audio_sidecar"),
                "skipped_files": len(skip_sources),
            }
        )

    def on_row(row: dict, index: int, total: int) -> None:
        if args.stream:
            emit_jsonl({"event": "row", "index": index, "total": total, "row": row})

    rows, audio_rows = plan_import(
        plan_items,
        video_library,
        photo_library,
        audit_dir,
        args.use_ollama,
        args.ollama_model,
        language,
        True,
        args.thumbnails,
        args.thumbnail_limit,
        args.layout,
        args.project,
        args.name_template,
        args.ollama_detail,
        on_row if args.stream else None,
        resume_video_targets,
        args.project_tags,
    )
    other_counts: dict[str, int] = {}
    other_bytes: dict[str, int] = {}
    for item in plan_items:
        if item.kind in {"video", "photo", "audio_sidecar"}:
            continue
        other_counts[item.kind] = other_counts.get(item.kind, 0) + 1
        other_bytes[item.kind] = other_bytes.get(item.kind, 0) + item.size
    summary = import_summary(audit_dir, True, rows, audio_rows, [], [])
    summary["total_files"] = len(items)
    summary["skipped_files"] = len(skip_sources)
    summary["language"] = language
    summary["other_counts"] = other_counts
    summary["other_gib"] = {k: size_gib(v) for k, v in other_bytes.items()}
    backup_roots = [(Path(backup_library).expanduser() / source.name).as_posix() for backup_library in backup_libraries(args.backup_library)]
    if backup_roots:
        summary["backup_root"] = backup_roots[0]
        summary["backup_roots"] = backup_roots
        summary["backup_files"] = sum(1 for i in plan_items if i.kind in {"video", "photo", "audio_sidecar"}) * len(backup_roots)
    result = {
        "summary": summary,
        "rows": rows,
        "audio_rows": audio_rows,
        "audit_dir": audit_dir.as_posix(),
    }
    (audit_dir / "plan.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.stream:
        emit_jsonl({"event": "summary", **result})
    else:
        print(json.dumps(result, ensure_ascii=False))
    return 0


def command_thumbnail(args: argparse.Namespace) -> int:
    path = Path(args.path).expanduser().resolve()
    audit_dir = Path(args.audit_dir).expanduser()
    if not path.exists():
        print(json.dumps({"thumbnail_path": "", "error": "source_not_found"}, ensure_ascii=False))
        return 1
    st = path.stat()
    encoder = ffprobe_tags(path).get("encoder", "")
    media = MediaFile(
        path=path,
        rel_path=Path(path.name),
        kind=media_kind(path),
        size=st.st_size,
        captured_at=parse_capture_time(path),
        device=device_from_text(path, encoder),
        profile=profile_marker(path),
        encoder=encoder,
    )
    thumb = make_thumbnail(media, audit_dir)
    print(json.dumps({"thumbnail_path": thumb, "error": "" if thumb else "thumbnail_failed"}, ensure_ascii=False))
    return 0 if thumb else 1


def command_prepare_rcj(args: argparse.Namespace) -> int:
    # A reusable version of the delivery rule used in the manual cleanup:
    # include explicit RCJ/RoboCup/robot material, exclude Robotics_Setup and generic competition-only names.
    source = Path(args.media_library).expanduser()
    target = Path(args.target).expanduser()
    audit_root = Path(args.audit_root).expanduser()
    audit_dir = audit_root / (dt.datetime.now().strftime("bunnycard_rcj_%Y%m%d_%H%M%S"))
    audit_dir.mkdir(parents=True, exist_ok=True)
    strong = re.compile(r"(rcj|rcka|robocup|robo[_ -]?cup|robot)", re.I)
    selected: list[Path] = []
    for path in iter_files(source):
        if path.suffix.lower() not in VIDEO_EXTS:
            continue
        rel = path.relative_to(source)
        category = rel.parts[1] if len(rel.parts) > 1 else ""
        if category == "Robotics_Setup":
            continue
        if category == "RoboCup" or strong.search(path.name):
            selected.append(path)
    rows: list[dict] = []
    for index, src in enumerate(sorted(selected), 1):
        rel = src.relative_to(source)
        dst = target / rel
        status, src_hash, dst_hash, final_dst = copy_verified(src, dst, args.dry_run)
        eprint(f"[{index}/{len(selected)}] {status} {rel}")
        rows.append(
            {
                "source_path": src.as_posix(),
                "relative_path": rel.as_posix(),
                "target_path": final_dst.as_posix(),
                "size_bytes": src.stat().st_size,
                "copy_status": status,
                "source_sha256": src_hash,
                "target_sha256": dst_hash,
            }
        )
    write_csv(audit_dir / "rcj_delivery_copy_log.csv", rows)
    summary = {"audit_dir": audit_dir.as_posix(), "files": len(rows), "gib": round(sum(int(r["size_bytes"]) for r in rows) / 1024**3, 3)}
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="bunnycard_core", description="BunnyCard media ingest and delivery engine")
    sub = parser.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan", help="scan a card and print media counts")
    scan.add_argument("--source", required=True)
    scan.set_defaults(func=command_scan)

    volumes = sub.add_parser("volumes", help="list mounted volumes and camera-card hints")
    volumes.add_argument("--camera-only", action="store_true")
    volumes.set_defaults(func=command_volumes)

    ollama_models = sub.add_parser("ollama-models", help="list local Ollama models for the GUI")
    ollama_models.set_defaults(func=command_ollama_models)

    plan = sub.add_parser("plan-card", help="preview a card import as JSON rows for the GUI")
    plan.add_argument("--source", required=True)
    plan.add_argument("--video-library", required=True)
    plan.add_argument("--photo-library", required=True)
    plan.add_argument("--audit-root", default="/Volumes/PS2000/_DuplicateAudit")
    plan.add_argument("--backup-library", action="append", default=[])
    plan.add_argument("--language", choices=["zh", "en"], default="zh")
    plan.add_argument("--layout", choices=["month_category", "project_tag"], default="month_category")
    plan.add_argument("--project", default="")
    plan.add_argument("--project-tags", default="")
    plan.add_argument("--name-template", default="")
    plan.add_argument("--thumbnails", action="store_true")
    plan.add_argument("--thumbnail-limit", type=int, default=48)
    plan.add_argument("--use-ollama", action="store_true")
    plan.add_argument("--ollama-model", default="llava")
    plan.add_argument("--ollama-detail", choices=["concise", "rich"], default="concise")
    plan.add_argument("--skip-source-list", default="")
    plan.add_argument("--stream", action="store_true")
    plan.set_defaults(func=command_plan_card)

    imp = sub.add_parser("import-card", help="copy/split a card into video and photo libraries with hash verification")
    imp.add_argument("--source", required=True)
    imp.add_argument("--video-library", required=True)
    imp.add_argument("--photo-library", required=True)
    imp.add_argument("--audit-root", default="/Volumes/PS2000/_DuplicateAudit")
    imp.add_argument("--backup-library", action="append", default=[])
    imp.add_argument("--language", choices=["zh", "en"], default="zh")
    imp.add_argument("--layout", choices=["month_category", "project_tag"], default="month_category")
    imp.add_argument("--project", default="")
    imp.add_argument("--project-tags", default="")
    imp.add_argument("--name-template", default="")
    imp.add_argument("--dry-run", action="store_true")
    imp.add_argument("--delete-source", action="store_true")
    imp.add_argument("--delete-sidecars", action="store_true")
    imp.add_argument("--use-ollama", action="store_true")
    imp.add_argument("--ollama-model", default="llava")
    imp.add_argument("--ollama-detail", choices=["concise", "rich"], default="concise")
    imp.add_argument("--stream", action="store_true")
    imp.set_defaults(func=command_import_card)

    thumb = sub.add_parser("thumbnail", help="generate one local thumbnail for the GUI")
    thumb.add_argument("--path", required=True)
    thumb.add_argument("--audit-dir", required=True)
    thumb.set_defaults(func=command_thumbnail)

    rcj = sub.add_parser("prepare-rcj", help="build an RCJ delivery drive from a media library")
    rcj.add_argument("--media-library", required=True)
    rcj.add_argument("--target", required=True)
    rcj.add_argument("--audit-root", default="/Volumes/PS2000/_DuplicateAudit")
    rcj.add_argument("--dry-run", action="store_true")
    rcj.set_defaults(func=command_prepare_rcj)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
