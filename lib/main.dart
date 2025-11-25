import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'glyph_paths.dart';

// Top-level cache and helpers so widget and painter share the same transforms
final Map<String, Path> _glyphCache = {};

Path _parseGlyph(String ch) {
  if (_glyphCache.containsKey(ch)) return _glyphCache[ch]!;
  final d = glyphD[ch];
  if (d != null && d.isNotEmpty) {
    try {
      final p = parseSvgPathData(d);
      _glyphCache[ch] = p;
      return p;
    } catch (e) {
      // fall through to fallback
    }
  }
  // fallback simple 'A' path (designed with y-down coords)
  final Path fallback = Path()
    ..moveTo(50, 5)
    ..lineTo(90, 95)
    ..lineTo(70, 95)
    ..lineTo(62, 72)
    ..lineTo(38, 72)
    ..lineTo(30, 95)
    ..lineTo(10, 95)
    ..close()
    ..moveTo(40, 60)
    ..lineTo(60, 60)
    ..lineTo(55, 50)
    ..lineTo(45, 50)
    ..close();
  fallback.fillType = PathFillType.evenOdd;
  _glyphCache[ch] = fallback;
  return fallback;
}

// Top-level control: only flip glyphs that are known to be in font (y-up) coordinates.
// Leave empty by default; add entries like `_glyphNeedsFlip['A'] = true;` if a glyph
// parsed from `glyphD` needs a vertical flip to match Flutter's y-down canvas.
final Map<String, bool> _glyphNeedsFlip = {
  // 'A': true, // uncomment if your 'A' came from a font and appears upside-down
};

// Returns a transformed Path that fits the glyph into the provided size.
// If the glyph was extracted from a font (exists in glyphD), we flip Y to
// convert from font (y-up) coordinates to Flutter canvas (y-down).
Path transformedGlyphForSize(String ch, Size size, {double padding = 0.78}) {
  final Path glyph = _parseGlyph(ch);
  final Rect lb = glyph.getBounds();
  final double w = lb.width == 0 ? 1.0 : lb.width;
  final double h = lb.height == 0 ? 1.0 : lb.height;
  // compute scale to fit both width and height
  final double scaleFit = padding * ( (size.width / w).clamp(0.0, double.infinity) ).compareTo((size.height / h).clamp(0.0, double.infinity)) < 0
      ? padding * (size.width / w)
      : padding * (size.height / h);

  // Use explicit per-glyph flip control instead of assuming presence in glyphD means y-up.
  final bool needsFlip = _glyphNeedsFlip[ch] ?? false;
  final double sx = scaleFit;
  final double sy = needsFlip ? -scaleFit : scaleFit;

  // center-based transform: translate to center, scale (with optional flip), translate back
  final Offset glyphCenter = lb.center;
  final Offset canvasCenter = Offset(size.width / 2, size.height / 2);

  final double tx = canvasCenter.dx - glyphCenter.dx * sx;
  final double ty = canvasCenter.dy - glyphCenter.dy * sy;

  final Float64List m = Float64List.fromList([
    sx, 0, 0, 0,
    0, sy, 0, 0,
    0, 0, 1, 0,
    tx, ty, 0, 1,
  ]);

  return glyph.transform(m);
}

void main() => runApp(const KidsDrawApp());

class KidsDrawApp extends StatelessWidget {
  const KidsDrawApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: DrawPage());
}

class DrawPage extends StatefulWidget {
  const DrawPage({super.key});
  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  String _currentChar = 'A';

  // New state for color and stroke width
  Color _strokeColor = Colors.deepPurple;
  // default inside the limited allowed range
  double _strokeWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kids Draw - (${_currentChar})'),
        actions: [
          IconButton(
            tooltip: 'Toggle vertical flip for $_currentChar',
            icon: Icon(Icons.flip),
            onPressed: () {
              setState(() {
                _glyphNeedsFlip[_currentChar] = !(_glyphNeedsFlip[_currentChar] ?? false);
              });
            },
          ),
          IconButton(
            tooltip: 'Clear strokes',
            icon: Icon(Icons.clear),
            onPressed: () => setState(() => _strokes.clear()),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Precompute transformed glyph for hit testing so widget and painter use same transform
        final Path hitPath = transformedGlyphForSize(_currentChar, size);

        return GestureDetector(
          onPanStart: (details) {
            // Only start a stroke if touch is inside the transformed glyph
            if (hitPath.contains(details.localPosition)) {
              setState(() {
                _current = [details.localPosition];
                _strokes.add(_current!);
              });
            } else {
              _current = null;
            }
          },
          onPanUpdate: (details) {
            // Only record points that lie inside the transformed glyph
            if (hitPath.contains(details.localPosition)) {
              setState(() => _current?.add(details.localPosition));
            }
          },
          onPanEnd: (_) => setState(() => _current = null),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _LetterMaskPainter(List.of(_strokes),
                  letter: _currentChar, color: _strokeColor, strokeWidth: _strokeWidth),
            ),
          ),
        );
      }),
      bottomNavigationBar: SizedBox(
        height: 180,
        child: Column(
          children: [
            // Color picker and stroke width slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Row(
                children: [
                  Text('Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  // few color choices
                  _buildColorChoice(Colors.deepPurple),
                  _buildColorChoice(Colors.redAccent),
                  _buildColorChoice(Colors.green),
                  _buildColorChoice(Colors.orange),
                  _buildColorChoice(Colors.blue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Text('W', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Slider(
                            min: 30,
                            max: 50,
                            divisions: 20,
                            value: _strokeWidth.clamp(30.0, 50.0),
                            onChanged: (v) => setState(() => _strokeWidth = v.clamp(30.0, 50.0)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(_strokeWidth.toStringAsFixed(0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // alphabet picker
            SizedBox(
              height: 68,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Row(
                  children: List.generate(26, (i) {
                    final ch = String.fromCharCode(65 + i);
                    final selected = ch == _currentChar;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentChar = ch;
                            _strokes.clear(); // clear strokes when switching letters
                          });
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected ? Colors.blueAccent : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? Colors.blue.shade700 : Colors.grey.shade400),
                            boxShadow: selected ? [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))] : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ch,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            SizedBox(
              height: 56,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildColorChoice(Color c) {
    final bool selected = c == _strokeColor;
    return GestureDetector(
      onTap: () => setState(() => _strokeColor = c),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6.0),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black54, width: 2) : null,
        ),
      ),
    );
  }
}

// Update painter to accept letter char so it renders same glyph
class _LetterMaskPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final String letter;
  final Color color;
  final double strokeWidth;
  _LetterMaskPainter(this.strokes, {this.letter = 'A', this.color = Colors.deepPurple, this.strokeWidth = 16.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Use the shared helper so painter and widget use identical transform
    final Path transformedLetter = transformedGlyphForSize(letter, size);

    // Draw a faint filled silhouette and a subtle outline as a guide
    canvas.drawPath(
      transformedLetter,
      Paint()
        ..color = Colors.grey.withAlpha(31) // ~0.12 * 255
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      transformedLetter,
      Paint()
        ..color = Colors.grey.withAlpha(89) // ~0.35 * 255
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..isAntiAlias = true,
    );

    // Stroke paint (child drawing)
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Offscreen layer - for production compute tighter bounds
    final Rect layerBounds = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(layerBounds, Paint());

    // Draw strokes (destination)
    for (final pts in strokes) {
      final Path p = _pathFromPoints(pts);
      canvas.drawPath(p, strokePaint);
    }

    // Mask paint (source) - keep only destination pixels inside the letter
    final Paint maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..isAntiAlias = true
      ..style = PaintingStyle.fill; // switch to stroke + strokeWidth for outline tracing

    canvas.drawPath(transformedLetter, maskPaint);
    canvas.restore();
  }

  Path _pathFromPoints(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) {
      path.lineTo(pts.first.dx + 0.1, pts.first.dy + 0.1);
      return path;
    }
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _LetterMaskPainter old) {
    return old.strokes.length != strokes.length || old.strokes != strokes || old.letter != letter || old.color != color || old.strokeWidth != strokeWidth;
  }
}
