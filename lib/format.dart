String formatCoins(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}

String formatMult(double value) {
  if (value >= 1000) {
    final scaled = value / 1000;
    final body = scaled >= 10
        ? scaled.toStringAsFixed(0)
        : scaled.toStringAsFixed(1);
    return '${body}kx';
  }
  if (value >= 100) return '${value.toStringAsFixed(0)}x';
  return '${value.toStringAsFixed(2)}x';
}
