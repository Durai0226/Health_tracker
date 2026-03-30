import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/finance_tables.dart';

part 'finance_dao.g.dart';

@DriftAccessor(tables: [
  Bills, 
  BillPayments, 
  BillCategories, 
  BillTemplates,
  BillActivities,
  CategoryKeywordMaps,
  BillSettingsTable,
  FinanceSettings,
])
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(AppDatabase db) : super(db);

  // ============ BILLS ============

  Future<List<Bill>> getAllBills() async {
    return await (select(bills)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .get();
  }

  Future<List<Bill>> getActiveBills() async {
    return await (select(bills)
      ..where((t) => t.isDeleted.equals(false) & t.isArchived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .get();
  }

  Future<List<Bill>> getUpcomingBills(int days) async {
    final endDate = DateTime.now().add(Duration(days: days));
    return await (select(bills)
      ..where((t) => t.isDeleted.equals(false) & 
                     t.isArchived.equals(false) &
                     t.dueDate.isBiggerOrEqualValue(DateTime.now()) &
                     t.dueDate.isSmallerThanValue(endDate))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .get();
  }

  Future<Bill?> getBill(String id) async {
    return await (select(bills)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveBill(BillsCompanion bill) async {
    await into(bills).insertOnConflictUpdate(bill);
  }

  Future<void> deleteBill(String id) async {
    await (delete(bills)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Bill>> watchBills() {
    return (select(bills)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .watch();
  }

  // ============ PAYMENTS ============

  Future<List<BillPayment>> getPaymentsForBill(String billId) async {
    return await (select(billPayments)
      ..where((t) => t.billId.equals(billId))
      ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
      .get();
  }

  Future<List<BillPayment>> getAllPayments({DateTime? fromDate, DateTime? toDate}) async {
    var query = select(billPayments);
    if (fromDate != null) {
      query = query..where((t) => t.paidAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((t) => t.paidAt.isSmallerThanValue(toDate));
    }
    return await (query..orderBy([(t) => OrderingTerm.desc(t.paidAt)])).get();
  }

  Future<void> addPayment(BillPaymentsCompanion payment) async {
    await into(billPayments).insert(payment);
  }

  Future<void> updatePayment(BillPaymentsCompanion payment) async {
    await (update(billPayments)..where((t) => t.id.equals(payment.id.value))).write(payment);
  }

  Future<void> deletePayment(String id) async {
    await (delete(billPayments)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deletePaymentsForBill(String billId) async {
    await (delete(billPayments)..where((t) => t.billId.equals(billId))).go();
  }

  Stream<List<BillPayment>> watchPayments() {
    return (select(billPayments)..orderBy([(t) => OrderingTerm.desc(t.paidAt)])).watch();
  }

  // ============ CATEGORIES ============

  Future<List<BillCategory>> getAllCategories() async {
    return await (select(billCategories)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();
  }

  Future<BillCategory?> getCategory(String id) async {
    return await (select(billCategories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> addBill(BillsCompanion bill) async {
    await into(bills).insertOnConflictUpdate(bill);
  }

  Future<void> saveCategory(BillCategoriesCompanion category) async {
    await into(billCategories).insertOnConflictUpdate(category);
  }

  Future<void> deleteCategory(String id) async {
    await (delete(billCategories)..where((t) => t.id.equals(id))).go();
  }

  // ============ TEMPLATES ============

  Future<List<BillTemplate>> getAllTemplates() async {
    return await (select(billTemplates)
      ..where((t) => t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]))
      .get();
  }

  Future<BillTemplate?> getTemplate(String id) async {
    return await (select(billTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveTemplate(BillTemplatesCompanion template) async {
    await into(billTemplates).insertOnConflictUpdate(template);
  }

  Future<void> deleteTemplate(String id) async {
    await (delete(billTemplates)..where((t) => t.id.equals(id))).go();
  }

  Future<List<BillTemplate>> getTemplatesNeedingGeneration(int windowDays) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: windowDays));
    return await (select(billTemplates)
      ..where((t) => t.isActive.equals(true) &
                     t.nextDueDate.isBiggerOrEqualValue(now) &
                     t.nextDueDate.isSmallerThanValue(endDate)))
      .get();
  }

  // ============ ACTIVITIES ============

  Future<List<BillActivity>> getActivitiesForBill(String billId) async {
    return await (select(billActivities)
      ..where((t) => t.billId.equals(billId))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }

  Future<List<BillActivity>> getRecentActivities({int limit = 50}) async {
    return await (select(billActivities)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit))
      .get();
  }

  Future<void> addActivity(BillActivitiesCompanion activity) async {
    await into(billActivities).insert(activity);
  }

  Future<void> deleteActivitiesForBill(String billId) async {
    await (delete(billActivities)..where((t) => t.billId.equals(billId))).go();
  }

  // ============ KEYWORD MAPS ============

  Future<List<CategoryKeywordMap>> getAllKeywordMaps() async {
    return await (select(categoryKeywordMaps)
      ..orderBy([(t) => OrderingTerm.desc(t.frequency)]))
      .get();
  }

  Future<CategoryKeywordMap?> getKeywordMap(String keyword) async {
    return await (select(categoryKeywordMaps)
      ..where((t) => t.keyword.equals(keyword.toLowerCase())))
      .getSingleOrNull();
  }

  Future<void> saveKeywordMap(CategoryKeywordMapsCompanion map) async {
    await into(categoryKeywordMaps).insertOnConflictUpdate(map);
  }

  Future<void> deleteKeywordMap(String id) async {
    await (delete(categoryKeywordMaps)..where((t) => t.id.equals(id))).go();
  }

  // ============ BILL SETTINGS ============

  Future<BillSettingsTableData?> getBillSettings() async {
    return await (select(billSettingsTable)
      ..where((t) => t.id.equals('default')))
      .getSingleOrNull();
  }

  Future<void> saveBillSettings(BillSettingsTableCompanion settings) async {
    await into(billSettingsTable).insertOnConflictUpdate(settings);
  }

  // ============ LEGACY SETTINGS ============

  Future<int?> getIntSetting(String key) async {
    final result = await (select(financeSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return result?.intValue;
  }

  Future<void> setIntSetting(String key, int value) async {
    await into(financeSettings).insertOnConflictUpdate(
      FinanceSettingsCompanion.insert(key: key, intValue: Value(value)),
    );
  }
}
