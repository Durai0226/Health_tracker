import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/health/insight.dart';
import '../../../core/health/mood_tag_insights.dart';
import '../../../core/health/mood_tags.dart';
import '../../../core/utils/calendar_day.dart';
import '../models/medicine_log.dart' show moodRatingLabels;
import '../models/mood_entry.dart';
import 'report_pdf_parts.dart';

/// One day in the window: its average mood and every tag on any entry that day.
class MoodDayScore {
  const MoodDayScore({
    required this.day,
    required this.score,
    required this.entries,
    required this.tags,
  });

  /// Local calendar day, at midnight.
  final DateTime day;

  /// 0 (Terrible) to 4 (Great): higher is better, the way [MoodTagInsights]
  /// reads it. The mood log itself runs the other way (0 = Great).
  final double score;

  final int entries;
  final Set<String> tags;

  String get label => MoodReportService.labelForScore(score);
}

/// A run of up to seven days and how they went.
class MoodWeekScore {
  const MoodWeekScore({
    required this.start,
    required this.end,
    required this.daysLogged,
    required this.score,
  });

  final DateTime start;
  final DateTime end;
  final int daysLogged;

  /// Null when nothing was logged that week: a gap is shown as a gap, not as a
  /// middling mood.
  final double? score;
}

/// What a mood report says about a window of days. Pure, so the screen and the
/// PDF cannot disagree.
class MoodReportSummary {
  const MoodReportSummary({
    required this.start,
    required this.end,
    required this.windowDays,
    required this.entries,
    required this.days,
    required this.average,
    required this.levelEntries,
    required this.weeks,
    required this.hardDays,
    required this.topTags,
    required this.patterns,
  });

  /// First and last local day of the window, both included.
  final DateTime start;
  final DateTime end;
  final int windowDays;

  /// Entries logged in the window.
  final int entries;

  /// The days with an entry, oldest first.
  final List<MoodDayScore> days;

  /// The mean of the days' scores — each day counts once, so a day logged four
  /// times does not outweigh four days logged once. Null with nothing logged.
  final double? average;

  /// Entries at each level of the log's own scale: index 0 is Great, 4 Terrible.
  final List<int> levelEntries;

  /// Newest first. Empty under two weeks (one block is just the average) and
  /// when nothing was logged at all (a column of gaps says nothing).
  final List<MoodWeekScore> weeks;

  /// Days rated Bad or Terrible, newest first.
  final List<MoodDayScore> hardDays;

  /// The tags on the most days, most first.
  final List<({String tag, int days})> topTags;

  /// "Mood tends to be better on days with a walk", when the days support it.
  final List<Insight> patterns;

  int get daysLogged => days.length;
  bool get isEmpty => entries == 0;

  String? get averageLabel =>
      average == null ? null : MoodReportService.labelForScore(average!);
}

class MoodReportService {
  const MoodReportService._();

  /// A day at or below this average counts as a hard one: Bad (1.0) or
  /// Terrible (0.0), or an average of the two with a day that went a little
  /// better.
  static const double hardDayScore = 1.5;

  /// The fewest days worth a week-by-week breakdown.
  static const int minDaysForWeeks = 14;

  /// Tags listed, and the fewest days one needs to be listed at all.
  static const int maxTopTags = 5;
  static const int minTagDays = 2;

  /// The mood label nearest [score] (0 Terrible … 4 Great).
  static String labelForScore(double score) =>
      moodRatingLabels[(4 - score).round().clamp(0, moodRatingLabels.length - 1)];

  /// [entries] as they fall in the [windowDays] days ending today.
  static MoodReportSummary summarize(
    List<MoodEntry> entries, {
    required int windowDays,
    DateTime? now,
  }) {
    final today = startOfDay(now ?? clock.now());
    final start = dayOffset(today, -(windowDays - 1));

    final inWindow = [
      for (final e in entries)
        if (!startOfDay(e.takenAt).isBefore(start) && !startOfDay(e.takenAt).isAfter(today)) e,
    ];

    final byDay = <DateTime, List<MoodEntry>>{};
    for (final e in inWindow) {
      (byDay[startOfDay(e.takenAt)] ??= []).add(e);
    }
    final days = [
      for (final d in byDay.entries)
        MoodDayScore(
          day: d.key,
          score: d.value
                  .map((e) => (moodRatingLabels.length - 1 - e.moodIndex))
                  .reduce((a, b) => a + b) /
              d.value.length,
          entries: d.value.length,
          tags: {for (final e in d.value) ...e.tags},
        ),
    ]..sort((a, b) => a.day.compareTo(b.day));

    final levels = List<int>.filled(moodRatingLabels.length, 0);
    for (final e in inWindow) {
      levels[e.moodIndex]++;
    }

    final tagDays = <String, int>{};
    for (final d in days) {
      for (final t in d.tags) {
        tagDays[t] = (tagDays[t] ?? 0) + 1;
      }
    }
    final topTags = [
      for (final t in tagDays.entries)
        if (t.value >= minTagDays) (tag: t.key, days: t.value),
    ]..sort((a, b) {
        final byCount = b.days.compareTo(a.days);
        return byCount != 0
            ? byCount
            : MoodTags.label(a.tag).compareTo(MoodTags.label(b.tag));
      });

    return MoodReportSummary(
      start: start,
      end: today,
      windowDays: windowDays,
      entries: inWindow.length,
      days: days,
      average: days.isEmpty
          ? null
          : days.map((d) => d.score).reduce((a, b) => a + b) / days.length,
      levelEntries: levels,
      weeks: windowDays >= minDaysForWeeks && days.isNotEmpty
          ? _weeks(days, start, today)
          : const [],
      hardDays: [
        for (final d in days.reversed)
          if (d.score <= hardDayScore) d,
      ],
      topTags: topTags.take(maxTopTags).toList(),
      patterns: MoodTagInsights.insights([
        for (final d in days) DayMood(day: d.day, score: d.score, tags: d.tags),
      ]),
    );
  }

  /// Blocks of seven days counted back from [end], so the latest is always a
  /// whole week; the oldest may be shorter.
  static List<MoodWeekScore> _weeks(
      List<MoodDayScore> days, DateTime start, DateTime end) {
    final out = <MoodWeekScore>[];
    var blockEnd = end;
    while (!blockEnd.isBefore(start)) {
      var blockStart = dayOffset(blockEnd, -6);
      if (blockStart.isBefore(start)) blockStart = start;
      final inBlock = [
        for (final d in days)
          if (!d.day.isBefore(blockStart) && !d.day.isAfter(blockEnd)) d,
      ];
      out.add(MoodWeekScore(
        start: blockStart,
        end: blockEnd,
        daysLogged: inBlock.length,
        score: inBlock.isEmpty
            ? null
            : inBlock.map((d) => d.score).reduce((a, b) => a + b) / inBlock.length,
      ));
      blockEnd = dayOffset(blockEnd, -7);
    }
    return out;
  }

  // ---- PDF -------------------------------------------------------------------
  //
  // Pure Dart (the `pdf` package needs no Flutter bindings), so it is testable
  // headlessly; the UI shares the bytes via `printing`. ASCII-only text, which is
  // why the report carries no notes: the default PDF font has no glyphs for most
  // of what people write, and a free-text diary line is not something to put in a
  // file that gets forwarded. Entries are shown as levels, tags and dates.

  /// Hard days listed in the PDF, most recent first.
  static const int maxHardDayRows = 12;

  static Future<Uint8List> buildPdf(
    MoodReportSummary s, {
    String? patientName,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? clock.now();
    final total = s.levelEntries.fold<int>(0, (a, b) => a + b);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      build: (context) => [
        _header(patientName, s.start, s.end, now),
        pw.SizedBox(height: 16),
        _summaryBox(
          big: s.averageLabel ?? '-',
          unit: 'average mood',
          caption: s.isEmpty
              ? 'Nothing logged in this period'
              : '${s.daysLogged} of ${s.windowDays} days logged  -  '
                  '${s.entries} ${s.entries == 1 ? 'entry' : 'entries'}',
        ),
        if (!s.isEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
              'The average is of the days logged: each day counts once, however '
              'many times it was logged.',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
          pw.SizedBox(height: 18),
          _heading('How the entries felt'),
          pw.SizedBox(height: 8),
          _table(
            ['Mood', 'Entries', 'Share'],
            [
              for (var i = 0; i < moodRatingLabels.length; i++)
                [
                  moodRatingLabels[i],
                  '${s.levelEntries[i]}',
                  total == 0 ? '-' : '${(s.levelEntries[i] * 100 / total).round()}%',
                ],
            ],
          ),
          if (s.weeks.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _heading('Week by week'),
            pw.SizedBox(height: 8),
            _table(
              ['Week', 'Days logged', 'Average'],
              [
                for (final w in s.weeks)
                  [
                    '${_date(w.start)} to ${_date(w.end)}',
                    '${w.daysLogged}',
                    w.score == null ? '-' : labelForScore(w.score!),
                  ],
              ],
            ),
          ],
          if (s.hardDays.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _heading('Days rated Bad or Terrible'),
            pw.SizedBox(height: 4),
            pw.Text(
                '${s.hardDays.length} of ${s.daysLogged} days logged'
                '${s.hardDays.length > maxHardDayRows ? '; the most recent $maxHardDayRows are listed' : ''}.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 8),
            _table(
              ['Date', 'Mood', 'Tags'],
              [
                for (final d in s.hardDays.take(maxHardDayRows))
                  [
                    _date(d.day),
                    d.label,
                    d.tags.isEmpty
                        ? '-'
                        : (d.tags.toList()..sort())
                            .map(MoodTags.label)
                            .join(', '),
                  ],
              ],
            ),
          ],
          if (s.topTags.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _heading('Most common tags'),
            pw.SizedBox(height: 8),
            _table(
              ['Tag', 'Days'],
              [
                for (final t in s.topTags) [MoodTags.label(t.tag), '${t.days}'],
              ],
            ),
          ],
          if (s.patterns.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _heading('Patterns in these entries'),
            pw.SizedBox(height: 8),
            for (final p in s.patterns) ...[
              pw.Text(p.title,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(p.detail, style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 8),
            ],
          ],
        ],
        pw.SizedBox(height: 20),
        pw.Text(
            'This report summarises the mood the person logged. It is not a '
            'screening or a diagnosis. If low mood is getting in the way of '
            'daily life, talk to a clinician or someone you trust.',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _header(
          String? patient, DateTime from, DateTime to, DateTime now) =>
      ReportPdfParts.header(
          title: 'Mood Report',
          patient: patient,
          period: '${_date(from)} to ${_date(to)}',
          generated: _date(now));

  static pw.Widget _heading(String text) => pw.Text(text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));

  static pw.Widget _summaryBox(
          {required String big, required String unit, required String caption}) =>
      ReportPdfParts.summaryBox(big: big, unit: unit, caption: caption);

  static pw.Widget _table(List<String> headers, List<List<String>> rows) =>
      ReportPdfParts.table(headers, rows);

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
