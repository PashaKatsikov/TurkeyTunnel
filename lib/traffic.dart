import 'dart:math';

import 'road_geom.dart';

class Vehicle {
  Vehicle({
    required this.lane,
    required this.sprite,
    required this.speed,
    this.killer = false,
  }) : y = carSpawnY;

  final int lane;
  final int sprite;
  final double speed;
  final bool killer;
  double y;
}

class Barrier {
  Barrier(this.lane, this.droppedAt);

  static const fallTime = 0.28;

  final int lane;
  final double droppedAt;

  double fall(double now) {
    final t = (now - droppedAt) / fallTime;
    if (t < 0) return 0;
    if (t > 1) return 1;
    return t;
  }
}

class Traffic {
  Traffic(this.laneCount, [Random? random])
    : _random = random ?? Random(),
      _speeds = <double>[] {
    for (var i = 0; i < laneCount; i++) {
      _speeds.add(620 + _random.nextDouble() * 1000);
    }
  }

  static const killerSpeed = 2400.0;

  final int laneCount;
  final Random _random;
  final List<double> _speeds;
  final List<Vehicle> cars = <Vehicle>[];
  final Set<int> _blocked = <int>{};
  double _wait = 0.3;

  void tick(double dt, {required int firstLane}) {
    _wait -= dt;
    if (_wait <= 0) {
      _spawn(firstLane);
      _wait = 0.45 + _random.nextDouble() * 0.7;
    }
    for (final car in cars) {
      final reach = car.y + car.speed * dt;
      final queued = !car.killer && _blocked.contains(car.lane);
      if (queued && car.y < carStopY) {
        car.y = reach > carStopY ? carStopY : reach;
      } else if (queued && car.y == carStopY) {
        continue;
      } else {
        car.y = reach;
      }
    }
    cars.removeWhere((car) => car.y > carExitY);
  }

  void _spawn(int firstLane) {
    if (laneCount == 0) return;
    final from = firstLane < 0 ? 0 : (firstLane >= laneCount ? 0 : firstLane);
    final span = min(laneCount - from, 9);
    final lane = from + _random.nextInt(span);
    if (_blocked.contains(lane)) return;
    for (final car in cars) {
      if (car.lane == lane && car.y < 700) return;
    }
    cars.add(_ordinary(lane));
  }

  Vehicle _ordinary(int lane) {
    return Vehicle(
      lane: lane,
      sprite: _random.nextInt(4),
      speed: _speeds[lane],
    );
  }

  /// A barrier lands in [lane]. Cars already overlapping its spot are
  /// cleared away, the rest queue behind it. Sometimes one is waiting there.
  void block(int lane) {
    _blocked.add(lane);
    cars.removeWhere(
      (car) =>
          car.lane == lane &&
          !car.killer &&
          car.y > carStopY &&
          car.y < barrierY + 350,
    );
    final waiting = cars.any((car) => car.lane == lane && car.y <= carStopY);
    if (!waiting && _random.nextDouble() < 0.6) cars.add(_ordinary(lane));
  }

  /// The car that ends the run, aimed so it meets the bird as it lands.
  void strike(int lane) {
    cars.removeWhere(
      (car) => car.lane == lane && !car.killer && car.y < hatchY + 300,
    );
    cars.add(
      Vehicle(
        lane: lane,
        sprite: _random.nextInt(4),
        speed: killerSpeed,
        killer: true,
      ),
    );
  }

  /// Lifts every barrier: queued cars roll on.
  void release() => _blocked.clear();
}
