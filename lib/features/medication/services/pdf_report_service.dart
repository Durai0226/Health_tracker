import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/doctor_pharmacy.dart';
import 'medicine_storage_service.dart';

class PdfReportService {
  static Future<void> generateAndShareReport() async {
    final pdf = pw.Document();
    
    // Fetch data
    final medicines = await MedicineCleanStorageService.getAllMedicines();
    final logs = await MedicineCleanStorageService.getAllLogs();
    final doctors = await MedicineCleanStorageService.getAllDoctors();
    
    // Sort logs by date descending
    logs.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    final recentLogs = logs.take(50).toList(); // Last 50 logs

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 20),
          _buildPatientSummary(medicines, doctors),
          pw.SizedBox(height: 20),
          _buildMedicinesList(medicines),
          pw.SizedBox(height: 20),
          _buildRecentLogs(recentLogs, medicines),
        ],
      ),
    );

    // Share PDF using Printing package which works on Web, iOS, Android, macOS, etc.
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'medication_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildHeader() {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Medication Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now())),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientSummary(List<EnhancedMedicine> medicines, List<Doctor> doctors) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Active Medications: ${medicines.where((m) => m.isActive).length}'),
              if (doctors.isNotEmpty)
                pw.Text('Primary Doctor: ${doctors.firstWhere((d) => d.isPrimary, orElse: () => doctors.first).name}'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicinesList(List<EnhancedMedicine> medicines) {
    final activeMeds = medicines.where((m) => m.isActive).toList();
    
    if (activeMeds.isEmpty) {
      return pw.Text('No active medications.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Current Medications', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Medicine', 'Dosage', 'Schedule', 'Purpose'],
          data: activeMeds.map((m) => [
            m.name,
            m.displayDosage,
            m.schedule.frequencyDescription,
            m.purpose ?? '-',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _buildRecentLogs(List<MedicineLog> logs, List<EnhancedMedicine> medicines) {
    if (logs.isEmpty) return pw.Container();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Recent Activity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Date/Time', 'Medicine', 'Status', 'Notes'],
          data: logs.map((log) {
            String medName = 'Unknown Medicine';
            try {
               final med = medicines.firstWhere((m) => m.id == log.medicineId);
               medName = med.name;
            } catch (_) {}

            return [
              DateFormat('MMM d, h:mm a').format(log.scheduledTime),
              medName,
              log.status.displayName,
              log.notes ?? log.skipNote ?? '-',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }
}
