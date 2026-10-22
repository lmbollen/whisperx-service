# whisperx-service

Local [whisperX](https://github.com/m-bain/whisperX) HTTP API (CPU), based on
[whisper-asr-webservice](https://github.com/ahmetoner/whisper-asr-webservice)
with whisperX upgraded to 3.8.6 (see `Dockerfile` for why and how).

Everything lives in this directory: models are cached in `./cache` (owned by
you), config in `.env`.

## Usage

```bash
cp .env.example .env              # optional, see Config below
docker compose up -d --build      # start (first request downloads models)
docker compose logs -f            # logs
docker compose down               # stop
```

### As a systemd service

```bash
./whisperx.sh install             # writes /etc/systemd/system/whisperx.service, enables + starts it
systemctl status whisperx
./whisperx.sh uninstall           # stops, disables, removes the unit and the image
```

The unit runs `docker compose` from this directory, so don't move it after
installing (or re-run `install`). Delete the folder afterwards to also remove
cached models and config.

- Swagger UI: http://localhost:9000/docs (bound to localhost only)
- Transcribe:
  ```bash
  curl -F "audio_file=@file.mp3" \
    "http://localhost:9000/asr?output=json&word_timestamps=true"
  ```
  `output` can be `txt`, `json`, `srt`, `vtt`, `tsv`.

## Config (`.env`)

- `ASR_MODEL`: `tiny`, `base`, `small`, `medium`, `large-v3`, `turbo`, ... (CPU: `small`/`medium` recommended)
- `HF_TOKEN`: enables speaker diarization (`&diarize=true`, optional
  `&min_speakers=N&max_speakers=M`). Accept the terms for
  `pyannote/speaker-diarization-community-1` on Hugging Face first.
- `UID`/`GID`: container user, defaults to `1000:1000`. Set them if your user
  differs and you run compose by hand (`whisperx.sh install` sets them for you).
