# whisperx-service

Local [whisperX](https://github.com/m-bain/whisperX) HTTP API (CPU), based on
[whisper-asr-webservice](https://github.com/ahmetoner/whisper-asr-webservice)
with whisperX upgraded to 3.8.6 (see `Dockerfile` for why and how).

Everything lives in this directory: models are cached in `./cache` (owned by
you), config in `.env`.

## Prerequisites

- Docker Engine with the **Compose v2 plugin** (`docker compose`, not the old
  `docker-compose`). On Ubuntu's `docker.io` package it's separate:
  `sudo apt install docker-compose-v2` (or `docker-compose-plugin` when using
  Docker's own apt repo). Check with `docker compose version`.
- ~7 GB free disk for the images, plus the models in `./cache`.
- For the systemd service: systemd and `sudo`.

## Usage

```bash
install -m 600 .env.example .env  # optional, see Config below (600: may hold HF_TOKEN)
docker compose up -d --build      # start (first request downloads models)
docker compose logs -f            # logs
docker compose down               # stop
```

Started this way, Docker restarts the container on failure and at boot
(`restart: unless-stopped`) until you `docker compose down`.

### As a systemd service

```bash
./whisperx.sh install             # writes /etc/systemd/system/whisperx.service, enables + starts it
systemctl status whisperx
journalctl -u whisperx -f         # logs
./whisperx.sh uninstall           # stops, disables, removes the unit and both docker images
```

Run it as your normal user; it uses `sudo` where needed, and the container
runs as you so `./cache` stays yours. Under systemd, systemd alone owns the
container (Docker's restart policy is disabled), so stop and start it with
`systemctl`, not `docker compose`. The unit runs compose from this directory,
so don't move it after installing (or re-run `install`).

`uninstall` removes the service, `whisperx-service:local` and the pinned base
image. To free everything, also delete this folder (cached models and `.env`)
and run `docker builder prune` for leftover build cache.

## API

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
