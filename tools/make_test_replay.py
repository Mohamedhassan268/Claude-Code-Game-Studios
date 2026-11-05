"""Writes the small replay the Godot tests read, using Python's zlib, so that those tests prove the two sides agree."""
import base64
import json
import zlib
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "tiny_replay.json"


def array(values: np.ndarray) -> dict:
    data = values.astype("<f4")
    return {"dtype": "float32", "rows": data.shape[0], "cols": data.shape[1], "zlib_b64": base64.b64encode(zlib.compress(data.tobytes())).decode()}


def step(t: int, path: list[list[float]], alive: bool) -> dict:
    return {"t": t, "day": 1, "hour": 8, "minute": 0, "path_m": path, "needs": {"hunger": 0.8, "thirst": 0.6}, "stress": 0.1, "injured": False, "alive": alive,
            "event": "none", "action": "rest", "probs": {"rest": 0.7, "hide": 0.3}, "reason": "A test.", "phase": "none"}


def main() -> None:
    elevation = np.arange(12, dtype=float).reshape(3, 4) * 10
    replay = {
        "schema": 1,
        "scenario": {"id": "tiny", "title": "Tiny", "place": "generated", "step_minutes": 120, "steps": 4, "seed": 1, "t0_local_hour": 8},
        "provenance": {"commit": None, "pack_hash": "test", "verdicts": {}, "evidence_label": "TEST", "player_directed": False},
        "grid": {"nx": 4, "ny": 3, "dx_m": 100.0, "x0_m": 1000.0, "y0_m": 2000.0, "stride": 2},
        "terrain": {"elevation": array(elevation), "land": array(np.ones((3, 4)))},
        "sites": {},
        "series": {},
        "hazards": {"pdc.active": {"changes": [0, 2], "frames": [array(np.zeros((3, 4))), array(np.ones((3, 4)))]}},
        "people": [{"id": 0, "name": "Test", "mind": "quantum", "outcome": "died", "cause": "test",
                    "steps": [step(0, [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0]], True), step(1, [[10.0, 10.0], [10.0, 10.0]], False)]}],
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(replay, sort_keys=True, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
