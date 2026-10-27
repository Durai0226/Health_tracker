import 'package:clock/clock.dart';

import '../../../core/health/overnight_body.dart';
import '../../../core/services/rest_day_store.dart';
import '../../biometrics/models/biometric_day.dart';
import '../../biometrics/models/biometric_metric.dart';
import '../../biometrics/services/biometrics_service.dart';
import 'sleep_service.dart';

/// Last night's body signals against the person's own usual, from the daily
/// biometrics the app already keeps.
class OvernightBody {
  const OvernightBody._();

  /// Days before the night that make the usual range.
  static const int historyDays = 28;

  /// "Rest mode" is offered after two nights in a row with this many signals
  /// outside their usual range, out of at least [offerMinChecked] checked.
  static const int offerMinOutside = 3;
  static const int offerMinChecked = 4;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The check for the night that ended on the morning of [day].
  static OvernightBodyCheck? checkFor(DateTime day) {
    final d = _day(day);
    final last = BiometricsService.getForDate(d);
    if (last == null) return null;
    final past = BiometricsService.getForRange(
        DateTime(d.year, d.month, d.day - historyDays),
        DateTime(d.year, d.month, d.day - 1));

    // One HRV statistic only; skin temperature is a change OR an absolute.
    final hrvMetric = last.hrvMetric;
    final skin = last.skinTempMetric;
    final useBodyTemp = last.skinTempC == null && last.bodyTempAvgC != null;

    double? skinOf(BiometricDay r) => useBodyTemp
        ? r.bodyTempAvgC
        : (r.skinTempMetric == skin ? r.skinTempC : null);

    List<double> series(double? Function(BiometricDay) pick) => [
          for (final r in past) ?pick(r),
        ];

    final tempSignal =
        skin == SkinTempMetric.deltaFromBaseline && !useBodyTemp
            ? BodySignal.temperatureChange
            : BodySignal.temperature;

    return OvernightBodyCheck.evaluate(
      last: {
        BodySignal.restingHr: last.restingHr?.toDouble(),
        BodySignal.hrv: hrvMetric == null ? null : last.hrvNightlyMs,
        BodySignal.breathing: last.respiratoryRateAvg,
        BodySignal.bloodOxygen: last.spo2Avg,
        tempSignal: skinOf(last),
      },
      history: {
        BodySignal.restingHr: series((r) => r.restingHr?.toDouble()),
        BodySignal.hrv: series(
            (r) => r.hrvMetric == hrvMetric ? r.hrvNightlyMs : null),
        BodySignal.breathing: series((r) => r.respiratoryRateAvg),
        BodySignal.bloodOxygen: series((r) => r.spo2Avg),
        tempSignal: series(skinOf),
      },
    );
  }

  /// How far the heart rate dropped on the night that ended on [day], from the
  /// hourly rates and that night's sleep.
  static NightHeartDip? dipFor(DateTime day) {
    final d = _day(day);
    final night = SleepService.getForDate(d);
    final wakeDay = BiometricsService.getForDate(d);
    final before = BiometricsService.getForDate(
        DateTime(d.year, d.month, d.day - 1));
    if (night == null || wakeDay == null || before == null) return null;
    return NightHeartDip.compute(
      dayBefore: before.hourlyHr,
      wakeDay: wakeDay.hourlyHr,
      bedtime: night.bedtime,
      wakeTime: night.wakeTime,
    );
  }

  /// Two nights running with most signals off, and today not already a rest day.
  static bool restOffered({DateTime? now}) {
    final today = _day(now ?? clock.now());
    if (RestDayStore.kindToday(now: today) != null) return false;
    bool off(DateTime d) {
      final c = checkFor(d);
      return c != null &&
          c.checked >= offerMinChecked &&
          c.outside >= offerMinOutside;
    }

    return off(today) && off(DateTime(today.year, today.month, today.day - 1));
  }
}
