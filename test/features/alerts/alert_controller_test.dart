import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/features/alerts/application/alert_provider.dart';
import 'package:spendly_android/features/budgets/application/budget_calculations.dart';
import 'package:spendly_android/features/budgets/application/budgets_provider.dart';

import '../../helpers/fake_alerts.dart';

BudgetProgress _food(double spent) {
  return BudgetProgress(
    budget: const Budget(category: 'Food', limit: 5000),
    spent: spent,
  );
}

ProviderContainer _container({
  required double spent,
  required FakeAlertStore store,
  required FakeNotificationService service,
}) {
  final container = ProviderContainer(
    overrides: [
      alertStoreProvider.overrideWithValue(store),
      notificationServiceProvider.overrideWithValue(service),
      budgetProgressProvider.overrideWithValue([_food(spent)]),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late FakeAlertStore store;
  late FakeNotificationService service;

  setUp(() {
    store = FakeAlertStore();
    service = FakeNotificationService();
  });

  group('AlertController', () {
    test('sends the 80% warning only once', () async {
      final c = _container(spent: 4200, store: store, service: service);

      await c.read(alertControllerProvider).check();
      await c.read(alertControllerProvider).check();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.title, 'Food budget: 84% used');
    });

    test('sends "reached" later, and never repeats it', () async {
      await _container(
        spent: 4200,
        store: store,
        service: service,
      ).read(alertControllerProvider).check();

      final later = _container(spent: 5100, store: store, service: service);
      await later.read(alertControllerProvider).check();
      await later.read(alertControllerProvider).check();

      expect(service.shown.map((n) => n.title), [
        'Food budget: 84% used',
        'Food budget limit reached',
      ]);
    });

    test('sends nothing when alerts are turned off', () async {
      store.enabled = false;
      final c = _container(spent: 5100, store: store, service: service);

      await c.read(alertControllerProvider).check();

      expect(service.attempts, 0);
    });

    test('retries later when the phone blocks notifications', () async {
      service.deliver = false;
      final c = _container(spent: 4200, store: store, service: service);

      await c.read(alertControllerProvider).check();
      expect(service.shown, isEmpty);
      expect(store.sent, isEmpty); // not marked as sent

      service.deliver = true;
      await c.read(alertControllerProvider).check();
      expect(service.shown, hasLength(1));
    });

    test('forgets records from earlier months', () async {
      store.sent = {'2020-01|Food|warning'};
      final c = _container(spent: 4200, store: store, service: service);

      await c.read(alertControllerProvider).check();

      expect(store.sent.any((k) => k.startsWith('2020-01')), isFalse);
      expect(store.sent, isNotEmpty);
    });
  });

  group('AlertSettingsNotifier', () {
    ProviderContainer settingsContainer() {
      final container = ProviderContainer(
        overrides: [
          alertStoreProvider.overrideWithValue(store),
          notificationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('asks for notification permission only once', () async {
      final notifier = settingsContainer().read(alertSettingsProvider.notifier);

      await notifier.askPermissionOnce();
      await notifier.askPermissionOnce();

      expect(service.permissionRequests, 1);
    });

    test('turning alerts on reports a denied permission', () async {
      store.enabled = false;
      service.permissionGranted = false;
      final notifier = settingsContainer().read(alertSettingsProvider.notifier);

      final granted = await notifier.setEnabled(true);

      expect(granted, isFalse);
      expect(store.enabled, isTrue);
    });

    test('turning alerts off does not ask for permission', () async {
      final notifier = settingsContainer().read(alertSettingsProvider.notifier);

      await notifier.setEnabled(false);

      expect(store.enabled, isFalse);
      expect(service.permissionRequests, 0);
    });

    test('a test notification is shown right away', () async {
      final notifier = settingsContainer().read(alertSettingsProvider.notifier);

      expect(await notifier.sendTestNotification(), isNull);
      expect(service.shown.single.body, 'Budget alerts are working.');
    });

    test(
      'a test notification explains when notifications are blocked',
      () async {
        service.deliver = false;
        final notifier = settingsContainer().read(
          alertSettingsProvider.notifier,
        );

        expect(await notifier.sendTestNotification(), contains('blocked'));
      },
    );

    test('a test notification reports a setup problem', () async {
      service.failPermission = true;
      final notifier = settingsContainer().read(alertSettingsProvider.notifier);

      expect(
        await notifier.sendTestNotification(),
        startsWith('Setup problem'),
      );
    });
  });
}
