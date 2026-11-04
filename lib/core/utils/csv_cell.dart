/// One cell of a CSV file: made safe to open, then quoted if it has to be.
///
/// The one place this is written. Two exports each had their own copy, and the copies
/// had already come apart: one quoted a cell with a carriage return or a space at
/// either end, the other did not — and a carriage return left bare ends the row in the
/// reader, which is a corrupted export for whoever pasted one into a note.
///
/// **Made safe to open.** A cell that begins `=`, `+`, `-` or `@` (or a tab or a
/// carriage return) is run as a formula by Excel and Sheets, so a reminder or a
/// medicine named `=HYPERLINK(...)` would do something on the doctor's computer when
/// the report is opened. A single quote in front makes it text.
String csvCell(String value) {
  var v = value;
  if (v.isNotEmpty && _runsAsFormula.contains(v[0])) v = "'$v";
  final needsQuotes = v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r') ||
      v.startsWith(' ') ||
      v.endsWith(' ');
  if (!needsQuotes) return v;
  return '"${v.replaceAll('"', '""')}"';
}

/// What starts a cell a spreadsheet will evaluate.
const Set<String> _runsAsFormula = {'=', '+', '-', '@', '\t', '\r'};
