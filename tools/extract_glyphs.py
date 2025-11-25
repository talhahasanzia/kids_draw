#!/usr/bin/env python3
"""
extract_glyphs.py

One-time script to extract SVG path `d` strings for a given set of characters from a TTF/OTF
and emit a Dart map `lib/glyph_paths.dart` containing `const Map<String, String> glyphD = {...}`.

Usage:
  python3 tools/extract_glyphs.py /path/to/font.ttf

Output:
  lib/glyph_paths.dart

Requires:
  pip install fonttools

Notes:
  - This script extracts glyph outlines for specified characters (A..Z by default).
  - Check the font license before distributing glyph outlines.
"""
import sys
import json
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

if len(sys.argv) < 2:
    print('Usage: python3 tools/extract_glyphs.py /path/to/font.ttf')
    sys.exit(1)

fontfile = sys.argv[1]
print('Opening', fontfile)
font = TTFont(fontfile)
glyphSet = font.getGlyphSet()
# build cmap mapping
cmap = font.getBestCmap()

result = {}
for ch in CHARS:
    cp = ord(ch)
    glyphName = cmap.get(cp)
    if glyphName is None:
        print(f'No glyph for {ch} in font')
        continue
    pen = SVGPathPen(glyphSet)
    glyph = glyphSet[glyphName]
    glyph.draw(pen)
    d = pen.getCommands()
    result[ch] = d

# Write Dart file
out_path = 'lib/glyph_paths.dart'
print('Writing', out_path)
with open(out_path, 'w') as f:
    f.write('// GENERATED FILE - glyph d strings (A-Z)\n')
    f.write('// Run tools/extract_glyphs.py to regenerate.\n\n')
    f.write('const Map<String, String> glyphD = {\n')
    for k in sorted(result.keys()):
        v = result[k]
        # escape triple quotes by using raw string literal in Dart (r'''...''')
        f.write(f"  '{k}': r'''{v}''',\n")
    f.write('};\n')

print('Done')

