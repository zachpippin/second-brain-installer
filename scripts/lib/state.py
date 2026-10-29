#!/usr/bin/env python3
"""Read and write installer state. This never writes inside the notes vault."""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def config_path() -> Path:
    return Path(os.environ["SB_CONFIG_DIR"]) / "config.json"


def state_dir() -> Path:
    path = Path(os.environ["SB_STATE_DIR"])
    path.mkdir(parents=True, exist_ok=True)
    return path


def load_json(path: Path, default):
    if not path.is_file():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def cmd_config_set(args) -> int:
    path = config_path()
    data = load_json(path, {})
    data[args.key] = args.value
    save_json(path, data)
    return 0


def cmd_config_get(args) -> int:
    data = load_json(config_path(), {})
    value = data.get(args.key, "")
    sys.stdout.write("" if value is None else str(value))
    return 0


def cmd_pin_set(args) -> int:
    path = config_path()
    data = load_json(path, {})
    pins = data.get("pins") or {}
    if args.version:
        pins[args.component] = args.version
    else:
        pins.pop(args.component, None)
    data["pins"] = pins
    save_json(path, data)
    return 0


def cmd_pin_get(args) -> int:
    data = load_json(config_path(), {})
    pins = data.get("pins") or {}
    sys.stdout.write(str(pins.get(args.component, "")))
    return 0


def cmd_versions_set(args) -> int:
    path = state_dir() / "versions.json"
    data = load_json(path, {})
    data[args.key] = args.value
    data["recorded_at"] = utc_now()
    save_json(path, data)
    return 0


def cmd_versions_get(args) -> int:
    data = load_json(state_dir() / "versions.json", {})
    sys.stdout.write(str(data.get(args.key, "")))
    return 0


def cmd_log(args) -> int:
    record = {
        "time": utc_now(),
        "component": args.component,
        "action": args.action,
        "from": args.from_version,
        "to": args.to_version,
        "result": args.result,
        "detail": args.detail,
    }
    log_path = state_dir() / "update-log.jsonl"
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")
    save_json(state_dir() / "last-update.json", record)
    return 0


def cmd_last(_args) -> int:
    path = state_dir() / "last-update.json"
    if not path.is_file():
        sys.stdout.write("none\n")
        return 0
    sys.stdout.write(path.read_text(encoding="utf-8"))
    return 0


def cmd_fingerprint(args) -> int:
    import hashlib

    vault = Path(args.vault)
    digest = hashlib.sha256()
    if vault.is_dir():
        files = sorted(path for path in vault.rglob("*") if path.is_file())
        for path in files:
            rel = path.relative_to(vault).as_posix()
            digest.update(rel.encode("utf-8"))
            digest.update(b"\0")
            digest.update(path.read_bytes())
            digest.update(b"\0")
    sys.stdout.write(digest.hexdigest())
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="second-brain installer state")
    sub = parser.add_subparsers(dest="cmd", required=True)

    config_set = sub.add_parser("config-set")
    config_set.add_argument("key")
    config_set.add_argument("value")
    config_set.set_defaults(func=cmd_config_set)

    config_get = sub.add_parser("config-get")
    config_get.add_argument("key")
    config_get.set_defaults(func=cmd_config_get)

    pin_set = sub.add_parser("pin-set")
    pin_set.add_argument("component")
    pin_set.add_argument("version", nargs="?", default="")
    pin_set.set_defaults(func=cmd_pin_set)

    pin_get = sub.add_parser("pin-get")
    pin_get.add_argument("component")
    pin_get.set_defaults(func=cmd_pin_get)

    versions_set = sub.add_parser("versions-set")
    versions_set.add_argument("key")
    versions_set.add_argument("value")
    versions_set.set_defaults(func=cmd_versions_set)

    versions_get = sub.add_parser("versions-get")
    versions_get.add_argument("key")
    versions_get.set_defaults(func=cmd_versions_get)

    log = sub.add_parser("log")
    log.add_argument("--component", required=True)
    log.add_argument("--action", required=True)
    log.add_argument("--from-version", default="")
    log.add_argument("--to-version", default="")
    log.add_argument("--result", required=True)
    log.add_argument("--detail", default="")
    log.set_defaults(func=cmd_log)

    last = sub.add_parser("last")
    last.set_defaults(func=cmd_last)

    fingerprint = sub.add_parser("fingerprint")
    fingerprint.add_argument("vault")
    fingerprint.set_defaults(func=cmd_fingerprint)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
