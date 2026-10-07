import 'package:flutter/material.dart';

// ============================================================
// OFF-RAMP BUTTONS — shared controls for the gray screens
// ============================================================
// Deliberately distinct from the game's wooden arcade buttons: a flat
// rounded pill with a press-scale. Labels pin cross-axis centre and
// line-height 1.0 so there is no baseline drift in either orientation
// (see the gray-part pitfalls doc §13). Tap target >= 48 dp.
// ============================================================

class RampButton extends StatefulWidget {
  const RampButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fill = const <Color>[Color(0xFFF2BE35), Color(0xFFE59413)],
    this.ink = const Color(0xFF3A2A08),
    this.width,
    this.height = 52,
  });

  final String label;
  final VoidCallback onTap;
  final List<Color> fill;
  final Color ink;
  final double? width;
  final double height;

  @override
  State<RampButton> createState() => _RampButtonState();
}

class _RampButtonState extends State<RampButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.fill,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quieter secondary action (used for "Skip"). Rendered as a real pill
/// with a translucent fill + border — not a low-opacity text link (see
/// the pitfalls doc §12: a faint Skip burns the one allowed prompt).
class RampGhostButton extends StatefulWidget {
  const RampGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.height = 48,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final double height;

  @override
  State<RampGhostButton> createState() => _RampGhostButtonState();
}

class _RampGhostButtonState extends State<RampGhostButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
