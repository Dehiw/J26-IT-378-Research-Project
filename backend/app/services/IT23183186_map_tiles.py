"""On-demand OSM tile proxy with seven-day persistent caching and app identification."""
import os
from pathlib import Path
import tempfile
import time
from uuid import uuid4

import httpx
from fastapi import HTTPException
from starlette.concurrency import run_in_threadpool

CACHE_DIR = Path(tempfile.gettempdir()) / "HiveSenseResearchMapTiles"
CACHE_SECONDS = 7 * 24 * 60 * 60


def _cached(path):
    try:
        if time.time() - path.stat().st_mtime < CACHE_SECONDS:
            return path.read_bytes()
    except OSError:
        pass
    return None


def _store(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(f".{uuid4().hex}.tmp")
    try:
        temporary.write_bytes(content)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


async def get_tile(z, x, y):
    path = CACHE_DIR / str(z) / str(x) / f"{y}.png"
    cached = await run_in_threadpool(_cached, path)
    if cached is not None:
        return cached
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(f"https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                headers={"User-Agent": "HiveSenseResearch/1.0"})
        if response.status_code != 200 or not response.content.startswith(b"\x89PNG\r\n\x1a\n"):
            raise HTTPException(502, "Map tiles are temporarily unavailable.")
        await run_in_threadpool(_store, path, response.content)
        return response.content
    except httpx.HTTPError as exc:
        raise HTTPException(502, "Could not load map tiles. Please retry.") from exc
