// Background plates are all 1566 px tall, so the world is those slices
// laid side by side. bank_left keeps the curb (it sits near x=620 of a
// 775-wide file). The asphalt patch skips the baked dashes. finish
// starts just before its curb, which is near x=120 of a 2067-wide file.
const artHeight = 1566.0;
const bankLeftWidth = 630.0;
const laneWidth = 600.0;
const finishSrcLeft = 100.0;
const finishFileWidth = 2067.0;
const finishWidth = finishFileWidth - finishSrcLeft;
const sidewalkX = 400.0;
const asphaltSrcLeft = 500.0;
const asphaltSrcWidth = 420.0;

const birdHeight = 400.0;
const carHeight = 400.0;

// The bird and every manhole share one row, a little below the middle of
// the plate. A barrier lands above that row.
const hatchY = 960.0;
const hatchHeight = 400.0;
const barrierY = 520.0;
const barrierWidth = 470.0;
const barrierHeight = barrierWidth * 365 / 749;
const barrierFall = 560.0;

// Traffic rolls top to bottom. A car queued behind a barrier stops with its
// nose against the barrier's top edge.
const carSpawnY = -230.0;
const carExitY = artHeight + 260;
const carStopY = barrierY - barrierHeight / 2 - carHeight / 2 + 22;

double finishStart(int lanes) => bankLeftWidth + lanes * laneWidth;

double carpetX(int lanes) => finishStart(lanes) + 420;

double worldWidth(int lanes) => finishStart(lanes) + finishWidth;

double laneCenter(int index) =>
    bankLeftWidth + laneWidth * index + laneWidth / 2;

double anchorX(int lane, int lanes) {
  if (lane < 0) return sidewalkX;
  if (lane >= lanes) return carpetX(lanes);
  return laneCenter(lane);
}

double cameraFor({
  required double viewWidth,
  required double scale,
  required double focus,
  required int lanes,
}) {
  if (scale <= 0) return 0;
  final viewArt = viewWidth / scale;
  final room = worldWidth(lanes) - viewArt;
  final hi = room < 0 ? 0.0 : room;
  final wanted = focus - viewArt * 0.28;
  if (wanted < 0) return 0;
  if (wanted > hi) return hi;
  return wanted;
}
