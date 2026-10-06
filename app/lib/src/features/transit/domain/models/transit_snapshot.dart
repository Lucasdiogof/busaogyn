class TransitSnapshot<T> {
  const TransitSnapshot({
    required this.data,
    required this.fetchedAt,
    required this.stale,
    required this.ageSeconds,
  });

  final T data;
  final DateTime? fetchedAt;
  final bool stale;
  final int ageSeconds;
}
