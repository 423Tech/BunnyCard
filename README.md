# BunnyCard

BunnyCard is a local media ingest tool for camera cards and delivery drives.

It copies videos and photos into separate libraries, renames files with a stable
`device_date_profile_tag_material` pattern, verifies every copied file with
SHA-256, and writes audit logs for each run.

## Run the GUI

```sh
cd /Users/davinci/Documents/GitHub/BunnyCard
swift run BunnyCard
```

Use **生成预览** to build a no-write table showing each source file, category,
target folder, new filename, size, and status. Select a row to inspect the full
source and target paths plus a local thumbnail preview. Use **开始复制** only
after the preview looks right.

The GUI shows mounted volume cards first. It filters out the system disk and
highlights volumes with camera-card structures such as `DCIM`, `PRIVATE`, and
`M4ROOT`.

## Default Paths

- Source card: `/Volumes/TF256GB_San`
- Video library: `/Volumes/PS2000/MediaLibrary`
- Photo library: `/Volumes/StudioDisk/lightroom`
- Audit logs: `/Volumes/PS2000/_DuplicateAudit`

## CLI

Scan a card:

```sh
python3 src/bunnycard_core.py scan --source /Volumes/TF256GB_San
```

Preview an import:

```sh
python3 src/bunnycard_core.py plan-card \
  --source /Volumes/TF256GB_San \
  --video-library /Volumes/PS2000/MediaLibrary \
  --photo-library /Volumes/StudioDisk/lightroom \
  --audit-root /Volumes/PS2000/_DuplicateAudit \
  --language zh \
  --layout project_tag \
  --project RCJ2026 \
  --thumbnails \
  --thumbnail-limit 48
```

Run the import for real while keeping source files on the card:

```sh
python3 src/bunnycard_core.py import-card \
  --source /Volumes/TF256GB_San \
  --video-library /Volumes/PS2000/MediaLibrary \
  --photo-library /Volumes/StudioDisk/lightroom \
  --audit-root /Volumes/PS2000/_DuplicateAudit \
  --backup-library /Volumes/PS2000/CardBackups \
  --language zh \
  --layout project_tag \
  --project RCJ2026 \
  --delete-sidecars
```

Add `--delete-source` only when the card should be cleared after verified copy.
When `--backup-library` is set, source deletion requires both the organized copy
and the original-structure backup to verify.

Prepare an RCJ delivery drive:

```sh
python3 src/bunnycard_core.py prepare-rcj \
  --media-library /Volumes/PS2000/MediaLibrary \
  --target /Volumes/Netac_256GB/RCJ_Delivery_20260628 \
  --audit-root /Volumes/PS2000/_DuplicateAudit
```

## Classification

The built-in rule classifier handles common paths and names:

- DJI is treated as a brand, not as automatic `航拍`.
- DJI Osmo/Pocket/Action media goes to `手持素材` unless visual/path evidence says otherwise.
- DJI drone model/path evidence goes to `航拍`; D-Log/D-Log M files include `dlogm`.
- RCJ/RoboCup material goes to `RoboCup`.
- Robot setup material goes to `机器人调试`.
- Graduation and sports field names get their own categories.

Use `--language en` or the GUI language segmented control for English folder and
filename tags.

For local visual classification, start Ollama and enable **Use local Ollama** in
the GUI, or pass `--use-ollama --ollama-model llava` in the CLI. The engine
samples one frame with `ffmpeg`; if Ollama fails, it falls back to rules.
`HTTP Error 404` from Ollama means the selected model is not installed. The GUI
lists local models and warns when no vision-capable model is detected.

## Audit Logs

Each run creates a folder like:

```text
/Volumes/PS2000/_DuplicateAudit/bunnycard_YYYYMMDD_HHMMSS_CARDNAME
```

The useful files are:

- `scan_manifest.csv`
- `copy_log.csv`
- `audio_sidecar_copy_log.csv`
- `backup_copy_log.csv`
- `source_delete_log.csv`
- `sidecar_delete_log.csv`
- `summary.json`

## TODO

- Proxy/transcode generation for editors.
- Face clustering / face-based grouping.
- System notification hooks after long imports.
- Export a compact human-readable PDF/HTML report.
