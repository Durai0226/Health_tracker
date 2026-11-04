import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';

/// The pieces the vitals and mood reports are both made of: a titled header, the
/// one big number in a tinted box, and a table.
///
/// They were written out in each service — word for word — so that a change to how a
/// report looks (the font, the colour, the header's layout) had to be made in each,
/// and one would be missed. The adherence report, the visit brief and the cycle
/// summary have copies of their own, which this does not touch.
class ReportPdfParts {
  const ReportPdfParts._();

  /// Title, who it is about (when it says), the period and when it was made.
  static pw.Widget header({
    required String title,
    String? patient,
    required String period,
    required String generated,
  }) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(AppStrings.productName,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.teal700)),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        if (patient != null && patient.trim().isNotEmpty)
          pw.Expanded(
              child: pw.Text('Patient: $patient', style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(
            child: pw.Text('Period: $period', style: const pw.TextStyle(fontSize: 10))),
        pw.Text('Generated: $generated', style: const pw.TextStyle(fontSize: 10)),
      ]),
      pw.SizedBox(height: 10),
      pw.Divider(color: PdfColors.grey400, thickness: .5),
    ]);
  }

  /// One big number, its unit, and a line of caption beside it.
  static pw.Widget summaryBox(
      {required String big, required String unit, required String caption}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(big,
            style: pw.TextStyle(
                fontSize: 30, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
        pw.SizedBox(width: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(unit,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        ),
        pw.Spacer(),
        pw.Expanded(
          child: pw.Text(caption,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ),
      ]),
    );
  }

  static pw.Widget table(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerStyle: pw.TextStyle(
          fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }
}
