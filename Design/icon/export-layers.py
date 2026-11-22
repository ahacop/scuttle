#!/usr/bin/env python3
"""Export the Icon Composer layers of Resources/Scuttle.icon from Design/icon/scuttle.svg.

Each <g id> in the SVG (motion, legs, body, window, face) is rendered alone, at 1024 px with a
transparent background, by headless Google Chrome, with the same ink filter in the same
coordinate space, so the layers register exactly. A `-dark` copy of each swaps the black ink
for a light one; icon.json uses it for the dark appearance. The background is not exported:
Icon Composer draws it as the document fill. Writes into Resources/Scuttle.icon/Assets and
leaves icon.json alone.

    python3 Design/icon/export-layers.py
"""
import pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Design/icon/scuttle.svg"
ASSETS = ROOT / "Resources/Scuttle.icon/Assets"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LAYERS = ["motion", "legs", "body", "window", "face"]
INK, LIGHT_INK = "stroke: #1d1b1a;", "stroke: #e6e0d4;"


def render(svg: str, out: pathlib.Path, scratch: pathlib.Path) -> None:
    page = scratch / (out.stem + ".svg")
    page.write_text(svg)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--default-background-color=00000000", "--window-size=1024,1024",
                    f"--screenshot={out}", page.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    master = SOURCE.read_text()
    if INK not in master:
        sys.exit(f"{SOURCE}: the ink style '{INK}' is missing")
    with tempfile.TemporaryDirectory() as tmp:
        scratch = pathlib.Path(tmp)
        for layer in LAYERS:
            svg = master
            for other in ["preview-bg"] + [l for l in LAYERS if l != layer]:
                svg = svg.replace(f'<g id="{other}"', f'<g id="{other}" display="none"', 1)
            render(svg, ASSETS / f"{layer}.png", scratch)
            render(svg.replace(INK, LIGHT_INK), ASSETS / f"{layer}-dark.png", scratch)
            print(f"exported {layer}.png and {layer}-dark.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
