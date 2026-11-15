#!/usr/bin/env python3

from __future__ import annotations

import sys
from pathlib import Path


def die(message: str) -> None:
    raise SystemExit(f"patch-multicontroller-wake.py: {message}")


if len(sys.argv) != 2:
    die("usage: patch-multicontroller-wake.py PATH/TO/ngc/bridge.py")

path = Path(sys.argv[1])

if not path.is_file():
    die(f"{path} does not exist")

text = path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# 1. Add short direct-probe timing constants.
# ---------------------------------------------------------------------------

constants_marker = "_CONNECTED_PROBE_ATTEMPT_S = 0.40"

if constants_marker not in text:
    anchor = "_CONNECT_ATTEMPTS = 16\n"

    if text.count(anchor) != 1:
        die(
            "expected exactly one '_CONNECT_ATTEMPTS = 16' anchor; "
            "upstream source changed"
        )

    replacement = (
        anchor
        + "\n"
        + "# When one or more controllers are already connected we must not\n"
        + "# start another BLE discovery scan, since scanning can destabilize\n"
        + "# live raw-L2CAP sessions. Instead, briefly probe the known MACs of\n"
        + "# disconnected paired controllers directly.\n"
        + "_CONNECTED_PROBE_ATTEMPT_S = 0.40\n"
        + "_CONNECTED_PROBE_INTERVAL_S = 1.0\n"
    )

    text = text.replace(anchor, replacement, 1)


# ---------------------------------------------------------------------------
# 2. Make _connect_sync() usable for both:
#
#    - the normal long wake-connect sequence
#    - our single short direct wake probe
# ---------------------------------------------------------------------------

new_signature_marker = "attempts: int = _CONNECT_ATTEMPTS"

if new_signature_marker not in text:
    old_signature = (
        "    def _connect_sync(self, mac: str) -> tuple[bool, str]:\n"
    )

    if text.count(old_signature) != 1:
        die(
            "expected exactly one original _connect_sync() signature; "
            "upstream source changed"
        )

    new_signature = (
        "    def _connect_sync(\n"
        "        self,\n"
        "        mac: str,\n"
        "        attempts: int = _CONNECT_ATTEMPTS,\n"
        "        attempt_s: float = _CONNECT_ATTEMPT_S,\n"
        "    ) -> tuple[bool, str]:\n"
    )

    text = text.replace(old_signature, new_signature, 1)

    signature_pos = text.index(new_signature)
    next_def_pos = text.find("\n    def ", signature_pos + len(new_signature))

    if next_def_pos == -1:
        next_def_pos = len(text)

    method = text[signature_pos:next_def_pos]

    old_attempt_assignment = "        attempt_s = _CONNECT_ATTEMPT_S\n"

    if method.count(old_attempt_assignment) != 1:
        die(
            "expected exactly one local attempt_s assignment inside "
            "_connect_sync(); upstream source changed"
        )

    method = method.replace(old_attempt_assignment, "", 1)

    old_loop = "            for attempt in range(_CONNECT_ATTEMPTS):\n"

    if method.count(old_loop) != 1:
        die(
            "expected exactly one _CONNECT_ATTEMPTS loop inside "
            "_connect_sync(); upstream source changed"
        )

    method = method.replace(
        old_loop,
        "            for attempt in range(max(1, attempts)):\n",
        1,
    )

    text = text[:signature_pos] + method + text[next_def_pos:]


# ---------------------------------------------------------------------------
# 3. Replace the "controller already connected -> do not scan" branch.
#
# The existing code intentionally refuses to scan once a controller has a
# live raw-L2CAP session because scanning can disconnect it.
#
# Instead of scanning, directly probe the already-paired MACs.
# ---------------------------------------------------------------------------

wake_probe_marker = "connected %s via direct wake probe"

if wake_probe_marker not in text:
    lines = text.splitlines(keepends=True)

    connected_indices = [
        i
        for i, line in enumerate(lines)
        if line.strip() == "if connected_count:"
    ]

    if len(connected_indices) != 1:
        die(
            "expected exactly one 'if connected_count:' branch; "
            "upstream source changed"
        )

    start = connected_indices[0]
    indent = lines[start][: len(lines[start]) - len(lines[start].lstrip())]

    scan_start = None

    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()

        if stripped.startswith("scan_on_s ="):
            scan_start = i
            break

    if scan_start is None:
        die(
            "could not find scan_on_s after connected_count branch; "
            "upstream source changed"
        )

    replacement = [
        f"{indent}if connected_count:\n",
        f"{indent}    # Never start BLE discovery while another controller\n",
        f"{indent}    # owns a live raw-L2CAP session. Discovery has been\n",
        f"{indent}    # observed to destabilize/drop existing connections.\n",
        f"{indent}    #\n",
        f"{indent}    # Instead, directly probe each disconnected paired MAC.\n",
        f"{indent}    # Sleeping controllers simply time out; after the user\n",
        f"{indent}    # wakes one, the raw LE connection can succeed without\n",
        f"{indent}    # starting another discovery session.\n",
        f"{indent}    hub._scanning = False\n",
        f"{indent}    hub._idle_scan_cycles = 0\n",
        "\n",
        f"{indent}    loop = asyncio.get_running_loop()\n",
        "\n",
        f"{indent}    for worker in disconnected:\n",
        f"{indent}        if worker.is_connected():\n",
        f"{indent}            continue\n",
        "\n",
        f"{indent}        mac = worker.entry.mac.upper()\n",
        "\n",
        f"{indent}        try:\n",
        f"{indent}            ok, detail = await loop.run_in_executor(\n",
        f"{indent}                None,\n",
        f"{indent}                hub._connect_sync,\n",
        f"{indent}                mac,\n",
        f"{indent}                1,\n",
        f"{indent}                _CONNECTED_PROBE_ATTEMPT_S,\n",
        f"{indent}            )\n",
        f"{indent}        except Exception as exc:  # noqa: BLE001\n",
        f"{indent}            ok, detail = False, str(exc)\n",
        "\n",
        f"{indent}        if ok:\n",
        f"{indent}            logger.info(\n",
        f'{indent}                "connected %s via direct wake probe",\n',
        f"{indent}                mac,\n",
        f"{indent}            )\n",
        f"{indent}        else:\n",
        f"{indent}            logger.debug(\n",
        f'{indent}                "direct wake probe %s failed (%s)",\n',
        f"{indent}                mac,\n",
        f"{indent}                detail,\n",
        f"{indent}            )\n",
        "\n",
        f"{indent}    await asyncio.sleep(_CONNECTED_PROBE_INTERVAL_S)\n",
        f"{indent}    continue\n",
        "\n",
    ]

    lines[start:scan_start] = replacement
    text = "".join(lines)


# ---------------------------------------------------------------------------
# Sanity checks.
# ---------------------------------------------------------------------------

required = (
    "_CONNECTED_PROBE_ATTEMPT_S = 0.40",
    "_CONNECTED_PROBE_INTERVAL_S = 1.0",
    "attempts: int = _CONNECT_ATTEMPTS",
    "attempt_s: float = _CONNECT_ATTEMPT_S",
    "range(max(1, attempts))",
    "connected %s via direct wake probe",
)

missing = [item for item in required if item not in text]

if missing:
    die(f"post-patch sanity check failed; missing: {missing!r}")


path.write_text(text, encoding="utf-8")

print(f"patched {path}")
