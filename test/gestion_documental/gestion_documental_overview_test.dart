import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_live_overview.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'documental_test_repository.dart';

void main() {
  test(
    'a late response cannot replace the newly selected month or filters',
    () async {
      final repository = DocumentalTestRepository();
      final requests = <Completer<DocumentalContext>>[];
      final live = DocumentalLiveOverview<DocumentalContext>(
        repository: repository,
        load: () {
          final request = Completer<DocumentalContext>();
          requests.add(request);
          return request.future;
        },
        contextOf: (value) => value,
      );
      addTearDown(live.dispose);
      final displayed = <DateTime>[];
      live.addListener(() {
        if (live.data != null) displayed.add(live.data!.today);
      });
      final first = live.refresh();
      await live.refresh(reset: true);
      await live.refresh(reset: true);
      expect(requests, hasLength(1));
      repository.todayOverride = DateTime(2028, 2, 29);
      requests.first.complete(await repository.loadContext());
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(2));
      expect(live.data, isNull);
      expect(live.loading, isTrue);
      repository.todayOverride = DateTime(2028, 3, 1);
      requests.last.complete(await repository.loadContext());
      await first;
      expect(displayed, everyElement(DateTime(2028, 3, 1)));
      expect(live.data!.today, DateTime(2028, 3, 1));
      expect(live.loading, isFalse);
      expect(live.error, isNull);
    },
  );

  test(
    'disposing while loading prevents late responses and queued reloads',
    () async {
      final repository = DocumentalTestRepository();
      final request = Completer<DocumentalContext>();
      var calls = 0, notifications = 0;
      final live = DocumentalLiveOverview<DocumentalContext>(
        repository: repository,
        load: () {
          calls++;
          return request.future;
        },
        contextOf: (value) => value,
      )..addListener(() => notifications++);
      final pending = live.refresh();
      await live.refresh(reset: true);
      live.dispose();
      final before = notifications;
      request.complete(await repository.loadContext());
      await pending;
      repository.events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(notifications, before);
      expect(live.data, isNull);
    },
  );
}
