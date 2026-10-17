import 'cafe_table_reservation_repository.dart';

bool cafeReservationInPeriod(CafeTableReservation reservation, String period, DateTime now) {
  final instant = now.toUtc();
  final local = instant.add(const Duration(hours:3));
  final today = DateTime.utc(local.year,local.month,local.day).subtract(const Duration(hours:3));
  return switch(period) {
    'Today' => reservation.startsAt.toUtc().isBefore(today.add(const Duration(days:1))) &&
      reservation.endsAt.toUtc().isAfter(today),
    'Upcoming' => reservation.startsAt.toUtc().isAfter(instant),
    'Past' => !reservation.endsAt.toUtc().isAfter(instant),
    _ => true,
  };
}
