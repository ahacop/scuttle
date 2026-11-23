#!/usr/bin/env python3
"""Writes the config a recording runs scuttle with: yours, with the settings the measures depend on set.

Borders get colours nothing else on screen has and gaps wide enough that two neighbours' borders don't touch, so
pixels.py can tell every border from the wallpaper and from the next one in the recording. Further settings come
as `table.key=value` arguments, such as `animations.resize=instant`.

Usage: config.py <out.toml> [table.key=value ...]
"""
import sys
import tomllib
from pathlib import Path

ACTIVE, INACTIVE, WIDTH, GAP = "#ff00ff", "#00ffff", 4, 16


def scalar(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        return "[" + ", ".join(scalar(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{key(k)} = {scalar(x)}" for k, x in v.items()) + " }"
    raise TypeError(type(v))


def key(k):
    return k if k.replace("-", "").replace("_", "").isalnum() else '"' + k.replace('"', '\\"') + '"'


def dump(table, path=()):
    """TOML for a table: its own values, then its sub-tables and arrays of tables."""
    lines, tables = [], []
    for k, v in table.items():
        if isinstance(v, dict):
            tables.append((k, v))
        elif isinstance(v, list) and v and all(isinstance(x, dict) for x in v):
            tables.append((k, v))
        else:
            lines.append(f"{key(k)} = {scalar(v)}")
    out = []
    if path and (lines or not tables):
        out.append("[" + ".".join(key(p) for p in path) + "]")
    out += lines
    for k, v in tables:
        if isinstance(v, list):
            for item in v:
                out += ["", "[[" + ".".join(key(p) for p in path + (k,)) + "]]"]
                out += [f"{key(a)} = {scalar(b)}" for a, b in item.items()]
        else:
            out += [""] + dump(v, path + (k,))
    return out


def parse(text):
    try:
        return tomllib.loads(f"v = {text}")["v"]
    except tomllib.TOMLDecodeError:
        return text


def main():
    out, settings = Path(sys.argv[1]), sys.argv[2:]
    user = Path.home() / ".config/scuttle/scuttle.toml"
    config = tomllib.loads(user.read_text()) if user.exists() else {}
    borders = config.setdefault("borders", {})
    borders.update({"enabled": True, "width": WIDTH, "active-color": ACTIVE, "inactive-color": INACTIVE, "order": "below"})
    borders.pop("rules", None)
    config["gaps"] = {"inner": GAP, "outer": GAP}
    config.setdefault("animations", {}).update({"enabled": True, "duration-ms": 200, "resize": "glide"})
    for setting in settings:
        path, value = setting.split("=", 1)
        *tables, name = path.split(".")
        table = config
        for t in tables:
            table = table.setdefault(t, {})
        table[name] = parse(value)
    out.write_text("\n".join(dump(config)) + "\n")


if __name__ == "__main__":
    main()
