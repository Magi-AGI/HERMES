"""HTTP client for the LedgeRPG server.

Thin wrapper over urllib so the driver has no third-party dependency.
Base URL is injected so a real server, a test stub, or a replay harness
can all plug in through the same interface.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Dict, Optional
from urllib import request
from urllib.error import HTTPError, URLError


@dataclass
class StartConfig:
    seed: int
    grid_size: int = 8
    step_limit: int = 100
    food_count: int = 5
    obstacle_count: int = 8


class LedgeRPGClient:
    def __init__(self, base_url: str = "http://127.0.0.1:8765", timeout: float = 5.0) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def start_episode(self, cfg: StartConfig) -> Dict[str, Any]:
        payload = {
            "seed": cfg.seed,
            "grid_size": cfg.grid_size,
            "step_limit": cfg.step_limit,
            "food_count": cfg.food_count,
            "obstacle_count": cfg.obstacle_count,
        }
        return self._post("/episode/start", payload)

    def step(self, episode_id: str, action_name: str, args: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        payload = {
            "episode_id": episode_id,
            "action": {"name": action_name, "args": args or {}},
        }
        return self._post("/episode/step", payload)

    def end_episode(self, episode_id: str) -> Dict[str, Any]:
        return self._post("/episode/end", {"episode_id": episode_id})

    def get_state(self, episode_id: str) -> Dict[str, Any]:
        url = f"{self.base_url}/episode/state?episode_id={episode_id}"
        req = request.Request(url, method="GET")
        return self._send(req)

    def _post(self, path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        req = request.Request(
            f"{self.base_url}{path}",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        return self._send(req)

    def _send(self, req: request.Request) -> Dict[str, Any]:
        try:
            with request.urlopen(req, timeout=self.timeout) as resp:
                raw = resp.read().decode("utf-8")
        except HTTPError as e:
            raise RuntimeError(f"LedgeRPG HTTP {e.code}: {e.read().decode('utf-8', 'ignore')}") from e
        except URLError as e:
            raise RuntimeError(f"LedgeRPG unreachable at {self.base_url}: {e.reason}") from e
        return json.loads(raw)
