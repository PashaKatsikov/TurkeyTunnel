// Bindings for native/turkey_core, bundled by hook/build.dart.
// Stateless math goes through k7; a live round is an opaque pointer.
// Keep the selectors in sync with native/turkey_core/src/ffi.rs.
@DefaultAsset('package:turkey_tunnel/turkey_core')
library;

import 'dart:ffi';

@Native<Double Function(Uint32, Double, Double, Double, Double, Double)>(
  symbol: 'k7',
  isLeaf: true,
)
external double _k7(int sel, double a, double b, double c, double d, double e);

@Native<Pointer<Void> Function(Uint32, Double, Uint64)>(
  symbol: 'r0',
  isLeaf: true,
)
external Pointer<Void> _r0(int diff, double stake, int seed);

@Native<Void Function(Pointer<Void>)>(symbol: 'r1', isLeaf: true)
external void _r1(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>, Uint32, Double)>(
  symbol: 'r2',
  isLeaf: true,
)
external double _r2(Pointer<Void> handle, int sel, double a);

const int _lanes = 1;
const int _chance = 2;
const int _step = 3;
const int _payout = 4;
const int _minStake = 5;
const int _opening = 6;
const int _pocket = 7;
const int _startingStake = 8;
const int _fitStake = 9;
const int _nudge = 10;
const int _canSpend = 11;
const int _debit = 12;
const int _credit = 13;
const int _stakeAfterSpend = 14;
const int _nonNegative = 15;
const int _broke = 16;

const int _roundLane = 1;
const int _roundSetLane = 2;
const int _roundMultiplier = 3;
const int _roundPayout = 4;
const int _roundDiesNext = 5;

double _m(int sel, [double a = 0, double b = 0, double c = 0]) {
  return _k7(sel, a, b, c, 0, 0);
}

int ttLanes(int diff) => _m(_lanes, diff.toDouble()).round();

double ttHitChance(int diff) => _m(_chance, diff.toDouble());

double ttStep(int diff, int index) =>
    _m(_step, diff.toDouble(), index.toDouble());

int ttPayout(double stake, double multiplier, double lane) {
  return _m(_payout, stake, multiplier, lane).round();
}

int ttMinStake() => _m(_minStake).round();

int ttOpening() => _m(_opening).round();

int ttPocket() => _m(_pocket).round();

int ttStartingStake() => _m(_startingStake).round();

int ttFitStake(double value, double balance) {
  return _m(_fitStake, value, balance).round();
}

int ttNudge(double stake, double direction, double balance) {
  return _m(_nudge, stake, direction, balance).round();
}

bool ttCanSpend(double amount, double balance) {
  return _m(_canSpend, amount, balance) != 0;
}

int ttDebit(double balance, double amount) {
  return _m(_debit, balance, amount).round();
}

int ttCredit(double balance, double amount) {
  return _m(_credit, balance, amount).round();
}

int ttStakeAfterSpend(double stake, double balance) {
  return _m(_stakeAfterSpend, stake, balance).round();
}

int ttNonNegative(double value) => _m(_nonNegative, value).round();

bool ttBroke(double balance) => _m(_broke, balance) != 0;

Pointer<Void> ttOpenRound(int diff, double stake, int seed) {
  return _r0(diff, stake, seed);
}

void ttCloseRound(Pointer<Void> handle) => _r1(handle);

int ttRoundLane(Pointer<Void> handle) => _r2(handle, _roundLane, 0).round();

void ttRoundSetLane(Pointer<Void> handle, int lane) {
  _r2(handle, _roundSetLane, lane.toDouble());
}

double ttRoundMultiplier(Pointer<Void> handle) {
  return _r2(handle, _roundMultiplier, 0);
}

int ttRoundPayout(Pointer<Void> handle) => _r2(handle, _roundPayout, 0).round();

bool ttRoundDiesNext(Pointer<Void> handle) {
  return _r2(handle, _roundDiesNext, 0) != 0;
}
