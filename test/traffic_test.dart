import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:turkey_tunnel/road_geom.dart';
import 'package:turkey_tunnel/traffic.dart';

void step(Traffic traffic, double seconds, {int firstLane = 0}) {
  var left = seconds;
  while (left > 0) {
    final dt = left < 0.01 ? left : 0.01;
    traffic.tick(dt, firstLane: firstLane);
    left -= dt;
  }
}

void main() {
  test('cars queue behind a barrier and never pass it', () {
    final traffic = Traffic(4, Random(7));
    traffic.block(1);
    step(traffic, 20);
    final lane = traffic.cars.where((car) => car.lane == 1).toList();
    expect(lane.length, lessThanOrEqualTo(1));
    for (final car in lane) {
      expect(car.y, lessThanOrEqualTo(carStopY));
    }
    traffic.release();
    step(traffic, 4);
    expect(
      traffic.cars.where((car) => car.lane == 1 && car.y == carStopY),
      isEmpty,
    );
  });

  test('traffic is sparse, one direction and not frozen', () {
    final traffic = Traffic(8, Random(3));
    var peak = 0;
    var moved = false;
    var previous = <Vehicle, double>{};
    for (var i = 0; i < 1000; i++) {
      traffic.tick(0.02, firstLane: 0);
      if (traffic.cars.length > peak) peak = traffic.cars.length;
      for (final car in traffic.cars) {
        final before = previous[car];
        if (before != null) {
          expect(car.y, greaterThanOrEqualTo(before));
          if (car.y > before) moved = true;
        }
      }
      previous = {for (final car in traffic.cars) car: car.y};
    }
    expect(moved, isTrue);
    expect(peak, lessThan(14));
  });

  test('lanes run at different speeds', () {
    final traffic = Traffic(10, Random(11));
    final speeds = <double>{};
    for (var i = 0; i < 600; i++) {
      traffic.tick(0.02, firstLane: 0);
      for (final car in traffic.cars) {
        speeds.add(car.speed);
      }
    }
    expect(speeds.length, greaterThan(3));
  });

  test('the striking car meets the bird as the hop lands', () {
    final traffic = Traffic(6, Random(5));
    traffic.strike(2);
    step(traffic, 0.30);
    final car = traffic.cars.firstWhere((car) => car.killer);
    final nose = car.y + carHeight / 2;
    final birdTop = hatchY - birdHeight / 2;
    expect(nose, lessThan(birdTop + 40));
    step(traffic, 0.08);
    expect(car.y + carHeight / 2, greaterThan(birdTop));
  });

  test('a barrier falls over a fraction of a second and lands', () {
    final barrier = Barrier(3, 1.0);
    expect(barrier.fall(0.5), 0);
    expect(barrier.fall(1.14), inExclusiveRange(0, 1));
    expect(barrier.fall(2.0), 1);
  });
}
