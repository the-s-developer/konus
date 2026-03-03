"""
Qwen3-ASR-1.7B Server
OpenAI-compatible /v1/audio/transcriptions endpoint
"""

import json
import os
import tempfile
import logging

import torch
import uvicorn
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
from contextlib import asynccontextmanager

logger = logging.getLogger("qwen3-asr")
logging.basicConfig(level=logging.INFO)

LANG_MAP = {
    "tr": "Turkish",
    "en": "English",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
    "pt": "Portuguese",
    "it": "Italian",
    "ar": "Arabic",
    "zh": "Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "ru": "Russian",
    "nl": "Dutch",
    "pl": "Polish",
    "sv": "Swedish",
    "da": "Danish",
    "fi": "Finnish",
    "cs": "Czech",
    "el": "Greek",
    "hu": "Hungarian",
    "ro": "Romanian",
    "hi": "Hindi",
    "th": "Thai",
    "vi": "Vietnamese",
    "id": "Indonesian",
    "ms": "Malay",
    "fa": "Persian",
    "tl": "Filipino",
}

model = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    logger.info("Loading Qwen3-ASR-1.7B...")
    from qwen_asr import Qwen3ASRModel

    model = Qwen3ASRModel.from_pretrained(
        "Qwen/Qwen3-ASR-1.7B",
        dtype=torch.bfloat16,
        device_map="cuda:0",
        max_inference_batch_size=32,
        max_new_tokens=512,
    )
    logger.info("Model loaded on cuda:0")
    yield
    logger.info("Shutting down")


app = FastAPI(title="Qwen3-ASR-1.7B", lifespan=lifespan)


@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    language: str = Form(None),
    initial_prompt: str = Form(None),
    stream: str = Form(None),
):
    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        # Map ISO code to language name, None = auto-detect
        lang = None
        if language:
            lang = LANG_MAP.get(language, language)

        results = model.transcribe(audio=tmp_path, language=lang)
        text = (results[0].text if results else "").strip()

        if stream and stream.lower() == "true":
            async def sse_generator():
                yield f"data: {json.dumps({'text': text})}\n\n"
                yield "data: [DONE]\n\n"
            return StreamingResponse(sse_generator(), media_type="text/event-stream")

        return JSONResponse({"text": text})

    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        return JSONResponse({"error": str(e)}, status_code=500)
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.get("/health")
async def health():
    return {
        "status": "ok" if model is not None else "loading",
        "model": "Qwen/Qwen3-ASR-1.7B",
        "device": "cuda" if torch.cuda.is_available() else "cpu",
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
