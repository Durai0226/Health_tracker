// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_dao.dart';

// ignore_for_file: type=lint
mixin _$FinanceDaoMixin on DatabaseAccessor<AppDatabase> {
  $BillsTable get bills => attachedDatabase.bills;
  $BillPaymentsTable get billPayments => attachedDatabase.billPayments;
  $BillCategoriesTable get billCategories => attachedDatabase.billCategories;
  $BillTemplatesTable get billTemplates => attachedDatabase.billTemplates;
  $BillActivitiesTable get billActivities => attachedDatabase.billActivities;
  $CategoryKeywordMapsTable get categoryKeywordMaps =>
      attachedDatabase.categoryKeywordMaps;
  $BillSettingsTableTable get billSettingsTable =>
      attachedDatabase.billSettingsTable;
  $FinanceSettingsTable get financeSettings => attachedDatabase.financeSettings;
  FinanceDaoManager get managers => FinanceDaoManager(this);
}

class FinanceDaoManager {
  final _$FinanceDaoMixin _db;
  FinanceDaoManager(this._db);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db.attachedDatabase, _db.bills);
  $$BillPaymentsTableTableManager get billPayments =>
      $$BillPaymentsTableTableManager(_db.attachedDatabase, _db.billPayments);
  $$BillCategoriesTableTableManager get billCategories =>
      $$BillCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.billCategories,
      );
  $$BillTemplatesTableTableManager get billTemplates =>
      $$BillTemplatesTableTableManager(_db.attachedDatabase, _db.billTemplates);
  $$BillActivitiesTableTableManager get billActivities =>
      $$BillActivitiesTableTableManager(
        _db.attachedDatabase,
        _db.billActivities,
      );
  $$CategoryKeywordMapsTableTableManager get categoryKeywordMaps =>
      $$CategoryKeywordMapsTableTableManager(
        _db.attachedDatabase,
        _db.categoryKeywordMaps,
      );
  $$BillSettingsTableTableTableManager get billSettingsTable =>
      $$BillSettingsTableTableTableManager(
        _db.attachedDatabase,
        _db.billSettingsTable,
      );
  $$FinanceSettingsTableTableManager get financeSettings =>
      $$FinanceSettingsTableTableManager(
        _db.attachedDatabase,
        _db.financeSettings,
      );
}
