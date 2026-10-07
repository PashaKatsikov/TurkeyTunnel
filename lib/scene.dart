import 'odds.dart';
import 'road_geom.dart';
import 'run.dart';
import 'traffic.dart';

/// Horizontal focus of the view. The play page eases it toward the bird
/// every frame; the painter only reads it.
class Camera {
  double focus = sidewalkX;
}

class Scene {
  Scene({
    required this.spec,
    required this.phase,
    required this.lane,
    required this.hop,
    required this.onCarpet,
    required this.deathLane,
    required this.wreckedAt,
    required this.cars,
    required this.barriers,
    required this.camera,
  });

  final DiffSpec spec;
  final RoundPhase phase;
  final int lane;
  final Hop? hop;
  final bool onCarpet;
  final int? deathLane;
  final double wreckedAt;
  final List<Vehicle> cars;
  final List<Barrier> barriers;
  final Camera camera;

  double birdX(double now) {
    final lanes = spec.lanes;
    final hop = this.hop;
    if (hop != null) {
      final from = anchorX(hop.from, lanes);
      final to = anchorX(hop.to, lanes);
      return from + (to - from) * hop.eased(now);
    }
    final dead = deathLane;
    if (phase == RoundPhase.wrecked && dead != null) {
      return anchorX(dead, lanes);
    }
    if (onCarpet) return anchorX(lanes, lanes);
    return anchorX(lane, lanes);
  }
}
