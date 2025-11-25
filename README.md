Kids Draw — saveLayer + BlendMode.dstIn demo

This small demo shows a simple tracing setup: children draw freehand strokes and a letter glyph is used as a mask (BlendMode.dstIn) so only strokes inside the glyph remain visible.

How to run

1. Ensure you have Flutter installed and set up.
2. From the project root run:

```bash
flutter pub get
flutter run
```

Notes

- The demo uses a hardcoded simple Path for letter "A" in `lib/main.dart`. To use SVG glyphs, add `path_drawing` to `pubspec.yaml` and parse `d` strings via `parseSvgPathData`.
- To switch to an outline tracing band, change the mask Paint to `PaintingStyle.stroke` and set a `strokeWidth` (mask width).

Next steps

- Extract a full alphabet from a TTF using fonttools and generate a Dart map of SVG `d` strings.
- Parse those strings at runtime (or pre-parse at build time) and replace the hardcoded Path.
- Add scoring via `Path.contains` or by sampling an offscreen image's alpha channel.

