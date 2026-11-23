#!/usr/bin/env python3
"""Builds public/map-styles/drop-dark.json: the OpenMapTiles "Dark Matter" style re-pointed at OpenFreeMap
(no API key) so the MapLibre / OpenStreetMap map has a real dark style when DROP is in dark mode.

Source style: https://github.com/openmaptiles/dark-matter-gl-style (BSD-3 code, design CC-BY 4.0 © OpenMapTiles).
Data: © OpenMapTiles, © OpenStreetMap contributors, served by OpenFreeMap.
Usage: python3 scripts/build-dark-map-style.py path/to/dark-matter-style.json
"""
import json, sys

src = json.load(open(sys.argv[1]))
FONT = {"Italic": ["Noto Sans Italic"]}
for layer in src["layers"]:
    tf = layer.get("layout", {}).get("text-font")
    if tf:
        layer["layout"]["text-font"] = FONT["Italic"] if any("Italic" in f for f in tf) else ["Noto Sans Regular"]
src["name"] = "DROP Dark"
src["id"] = "drop-dark"
src["metadata"] = {"attribution": "© OpenMapTiles © OpenStreetMap contributors, OpenFreeMap; style based on OpenMapTiles Dark Matter (CC-BY 4.0)"}
src["sources"] = {"openmaptiles": {"type": "vector", "url": "https://tiles.openfreemap.org/planet",
                                    "attribution": "© OpenMapTiles © OpenStreetMap contributors"}}
src["glyphs"] = "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf"
json.dump(src, open("public/map-styles/drop-dark.json", "w"), indent=1, ensure_ascii=False)
print("layers:", len(src["layers"]))
