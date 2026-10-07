import 'package:flutter/material.dart';

class ArcadeButton extends StatelessWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.detail,
    this.foreground = Colors.white,
    this.height = 48,
  });

  final String label;
  final String? detail;
  final Color color;
  final Color foreground;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spoken = detail == null ? label : '$label $detail';
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: spoken,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: Center(child: _face()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face() {
    final detailText = detail;
    if (detailText == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              detailText,
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
