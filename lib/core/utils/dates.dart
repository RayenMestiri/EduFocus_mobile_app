/// Date helpers shared across features.
///
/// The backend stores calendar dates as `YYYY-MM-DD` strings
/// (DayPlan.date, Todo.date, StudySession.date).
String todayYmd([DateTime? now]) {
  final d = now ?? DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
