String formatCount(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}к';
  }
  return '$n';
}
