abstract final class AppDateTime {
  static String ymdHm(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  static String updatedAgo(DateTime value, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(value);

    if (diff.inMinutes < 1) {
      return 'Updated just now';
    }
    if (diff.inHours < 1) {
      return 'Updated ${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return 'Updated ${diff.inHours}h ago';
    }
    return 'Updated ${diff.inDays}d ago';
  }
}
