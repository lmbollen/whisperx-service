# Upgrade the webservice's bundled whisperX (3.7.2 / pyannote 3.4, broken on
# torch >= 2.6) to whisperX 3.8.6, which uses pyannote.audio 4.
# Pinned by digest (= webservice v1.10.0) so upstream changes can't break the
# build; bump deliberately and check that the sed patches below still apply.
FROM onerahmet/openai-whisper-asr-webservice@sha256:0616c3d5fc6924e9d59aa8a7a3a944fbe8f3a5d701e5fc1fa2ce5b933dfecb73

# CPU-only torch first, so whisperx doesn't pull the CUDA wheels from PyPI
RUN /app/.venv/bin/pip install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cpu \
      "torch~=2.8.0" "torchaudio~=2.8.0" "torchvision~=0.23.0" \
 && /app/.venv/bin/pip install --no-cache-dir \
      --extra-index-url https://download.pytorch.org/whl/cpu \
      "whisperx==3.8.6"

# whisperX 3.8 renamed use_auth_token -> token and inserted num_speakers as the
# 2nd positional arg of DiarizationPipeline.__call__; pass everything by keyword.
# The greps make the build fail if the upstream code changes and the patch no longer applies.
RUN f=/app/app/asr_models/mbain_whisperx_engine.py \
 && sed -i \
      -e 's/use_auth_token=CONFIG.HF_TOKEN/token=CONFIG.HF_TOKEN/' \
      -e "s/self.model\['diarize_model'\](audio, min_speakers, max_speakers)/self.model['diarize_model'](audio, min_speakers=min_speakers, max_speakers=max_speakers)/" \
      "$f" \
 && grep -q 'token=CONFIG.HF_TOKEN' "$f" \
 && grep -q 'min_speakers=min_speakers, max_speakers=max_speakers' "$f"
