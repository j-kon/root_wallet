extension NumX on num {
  int get sats => (this * 100000000).round();
  double get btc => this / 100000000;
}
