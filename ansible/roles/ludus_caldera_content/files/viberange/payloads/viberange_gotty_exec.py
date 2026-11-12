#!/usr/bin/env python3
"""Execute one bounded command through the Kubernetes Goat GoTTY terminal."""

from __future__ import annotations

import argparse
import base64
import json
import re
import sys
import time
import urllib.request
import uuid

import websocket

ANSI_RE = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="GoTTY base URL")
    parser.add_argument("--command-b64", required=True, help="Base64-encoded shell command")
    parser.add_argument("--timeout", type=int, default=45)
    return parser.parse_args()


def fetch_token(base_url: str) -> str:
    with urllib.request.urlopen(base_url.rstrip("/") + "/auth_token.js", timeout=10) as response:
        body = response.read().decode("utf-8", errors="replace")
    match = re.search(r"gotty_auth_token\s*=\s*['\"]([^'\"]*)", body)
    if not match:
        raise RuntimeError("GoTTY auth token was not present")
    return match.group(1)


def main() -> int:
    args = parse_args()
    base_url = args.url.rstrip("/") + "/"
    command = base64.b64decode(args.command_b64).decode("utf-8")
    marker = f"__VIBERANGE_RC_{uuid.uuid4().hex}__"
    wrapped = f"{command.rstrip()}\nrc=$?\nprintf '\\n{marker}%s\\n' \"$rc\"\n"
    ws_url = re.sub(r"^http", "ws", base_url) + "ws"

    socket = websocket.create_connection(
        ws_url,
        subprotocols=["webtty"],
        timeout=5,
        origin=base_url.rstrip("/"),
    )
    try:
        socket.send(json.dumps({"Arguments": "", "AuthToken": fetch_token(base_url)}))
        socket.send("3" + json.dumps({"columns": 160, "rows": 40}))
        socket.send("1" + wrapped + "\r")
        deadline = time.monotonic() + args.timeout
        output = ""
        return_code: int | None = None
        while time.monotonic() < deadline:
            socket.settimeout(min(2, max(0.1, deadline - time.monotonic())))
            try:
                message = socket.recv()
            except websocket.WebSocketTimeoutException:
                continue
            if not message:
                continue
            if isinstance(message, bytes):
                message = message.decode("utf-8", errors="replace")
            if message[0] == "1":
                output += base64.b64decode(message[1:]).decode("utf-8", errors="replace")
                match = re.search(re.escape(marker) + r"(\d+)", output)
                if match:
                    return_code = int(match.group(1))
                    break
            elif message[0] == "2":
                socket.send("2")
        cleaned = ANSI_RE.sub("", output).replace("\r", "")
        cleaned = re.sub(re.escape(marker) + r"\d+", "", cleaned)
        sys.stdout.write(cleaned)
        if return_code is None:
            raise RuntimeError("timed out waiting for bounded command completion")
        return return_code
    finally:
        socket.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, websocket.WebSocketException) as exc:
        print(f"viberange_gotty_exec: {exc}", file=sys.stderr)
        raise SystemExit(1)
