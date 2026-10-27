import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/home/services/today_order.dart';

void main() {
  const mine = ['water', 'medicine', 'weekly', 'activity'];

  group('normalise', () {
    test('a missing or unreadable order is the default one', () {
      expect(TodayOrder.normalise(null), todayCardIds);
      expect(TodayOrder.normalise('water'), todayCardIds);
      expect(TodayOrder.normalise(const []), todayCardIds);
    });

    test('a saved order is kept', () {
      expect(TodayOrder.normalise(mine), mine);
    });

    test('unknown ids and repeats are dropped', () {
      expect(
          TodayOrder.normalise(
              ['weekly', 'sleep', 'weekly', 'water', 3, 'medicine']),
          ['weekly', 'water', 'medicine', 'activity']);
    });

    test('a card the saved order has never heard of goes on the end', () {
      expect(TodayOrder.normalise(['activity', 'water']),
          ['activity', 'water', 'medicine', 'weekly']);
    });
  });

  group('nothing needs you', () {
    test('the order is the person\'s own, and nothing is said', () {
      final a = TodayOrder.arrange(userOrder: mine);
      expect(a.order, mine);
      expect(a.promoted, isNull);
      expect(a.reason, isNull);
    });

    test('hidden cards are left out', () {
      final a = TodayOrder.arrange(userOrder: mine, hidden: {'medicine'});
      expect(a.order, ['water', 'weekly', 'activity']);
    });
  });

  group('one card is lifted', () {
    test('a due dose lifts Medicine and the rest keep their order', () {
      final a = TodayOrder.arrange(
          userOrder: mine, needs: const TodayNeeds(dosesDue: 2));
      expect(a.order, ['medicine', 'water', 'weekly', 'activity']);
      expect(a.promoted, 'medicine');
      expect(a.reason, '2 doses are due');
    });

    test('one dose reads as one dose', () {
      final a = TodayOrder.arrange(
          userOrder: mine, needs: const TodayNeeds(dosesDue: 1));
      expect(a.reason, '1 dose is due');
    });

    test('an overdue reminder lifts Focus & reminders', () {
      final a = TodayOrder.arrange(
          userOrder: todayCardIds,
          needs: const TodayNeeds(remindersOverdue: 3));
      expect(a.order, ['activity', 'medicine', 'water', 'weekly']);
      expect(a.promoted, 'activity');
      expect(a.reason, '3 reminders are overdue');
    });

    test('one reminder reads as one reminder', () {
      final a = TodayOrder.arrange(
          userOrder: todayCardIds,
          needs: const TodayNeeds(remindersOverdue: 1));
      expect(a.reason, '1 reminder is overdue');
    });

    test('water well behind lifts Water, to the nearest 50 ml', () {
      final a = TodayOrder.arrange(
          userOrder: ['medicine', 'weekly', 'activity', 'water'],
          needs: const TodayNeeds(waterBehindMl: 470));
      expect(a.order.first, 'water');
      expect(a.reason, 'about 450 ml behind');
    });

    test('water only a little behind does not move anything', () {
      final a = TodayOrder.arrange(
          userOrder: ['medicine', 'weekly', 'activity', 'water'],
          needs: const TodayNeeds(waterBehindMl: 399));
      expect(a.order.last, 'water');
      expect(a.promoted, isNull);
    });

    test('exactly at the threshold counts', () {
      final a = TodayOrder.arrange(
          userOrder: ['medicine', 'weekly', 'activity', 'water'],
          needs: const TodayNeeds(waterBehindMl: 400));
      expect(a.promoted, 'water');
    });
  });

  group('only one moves', () {
    const everything =
        TodayNeeds(dosesDue: 1, remindersOverdue: 2, waterBehindMl: 900);

    test('medicine outranks reminders and water', () {
      final a = TodayOrder.arrange(
          userOrder: ['water', 'weekly', 'activity', 'medicine'],
          needs: everything);
      expect(a.order, ['medicine', 'water', 'weekly', 'activity']);
    });

    test('reminders outrank water', () {
      final a = TodayOrder.arrange(
          userOrder: ['water', 'weekly', 'medicine', 'activity'],
          needs: const TodayNeeds(remindersOverdue: 2, waterBehindMl: 900));
      expect(a.order.first, 'activity');
      expect(a.order, ['activity', 'water', 'weekly', 'medicine']);
    });

    test('a hidden card is never lifted: the next need takes the top', () {
      final a = TodayOrder.arrange(
          userOrder: ['water', 'weekly', 'activity', 'medicine'],
          hidden: {'medicine'},
          needs: everything);
      expect(a.promoted, 'activity');
      expect(a.order, ['activity', 'water', 'weekly']);
    });

    test('with everything hidden but the weekly strip, nothing moves', () {
      final a = TodayOrder.arrange(
          userOrder: mine,
          hidden: {'medicine', 'water', 'activity'},
          needs: everything);
      expect(a.order, ['weekly']);
      expect(a.promoted, isNull);
    });
  });

  group('already on top', () {
    test('nothing moved, so nothing is explained', () {
      final a = TodayOrder.arrange(
          userOrder: todayCardIds, needs: const TodayNeeds(dosesDue: 4));
      expect(a.order, todayCardIds);
      expect(a.promoted, isNull);
      expect(a.reason, isNull);
    });

    test('top among the VISIBLE cards is enough', () {
      final a = TodayOrder.arrange(
          userOrder: ['water', 'medicine', 'weekly', 'activity'],
          hidden: {'water'},
          needs: const TodayNeeds(dosesDue: 1));
      expect(a.order, ['medicine', 'weekly', 'activity']);
      expect(a.promoted, isNull);
    });
  });

  test('switched off, the order is exactly the person\'s own', () {
    final a = TodayOrder.arrange(
        userOrder: mine,
        promote: false,
        needs: const TodayNeeds(
            dosesDue: 5, remindersOverdue: 5, waterBehindMl: 2000));
    expect(a.order, mine);
    expect(a.promoted, isNull);
  });

  test('a dirty saved order cannot lose or duplicate a card', () {
    final a = TodayOrder.arrange(
        userOrder: ['weekly', 'weekly', 'nonsense'],
        needs: const TodayNeeds(dosesDue: 1));
    expect(a.order.toSet(), todayCardIds.toSet());
    expect(a.order.length, todayCardIds.length);
    expect(a.order.first, 'medicine');
  });
}
