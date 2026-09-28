/// Operation records a physical count when the card is saved (there is no
/// backdating field). The server's save timestamp is the authoritative instant.
/// Older clients wrote counted_at as local time without an offset, which
/// PostgreSQL interpreted as UTC and shifted the inventory cutoff by hours.
DateTime? manualYardCountTime(Map<String, dynamic> row) {
  DateTime? parse(dynamic value) =>
      value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
  return parse(row['updated_at']) ?? parse(row['counted_at']);
}
