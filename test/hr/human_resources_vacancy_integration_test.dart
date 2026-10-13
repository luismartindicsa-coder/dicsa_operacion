import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/hr/human_resources_personnel_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_theme.dart';
import 'package:dicsa_operacion/app/hr/vacancies/hr_staffing.dart';
import 'package:dicsa_operacion/app/hr/vacancies/hr_vacancy_alerts.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final employee = <String, dynamic>{};
  final writes = <Map<String, dynamic>>[];
  bool loseReply = false;
  String? error;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://hr-vacancies-test.invalid',
      anonKey: 'synthetic',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        expectSync(r.url.host, 'hr-vacancies-test.invalid');
        final path = r.url.pathSegments.last;
        dynamic result;
        if (r.method == 'GET' && path == 'hr_employee_profiles') {
          result = [employee];
        } else if (r.method == 'GET' && path == 'hr_employee_documents') {
          result = [];
        } else if (r.method == 'PATCH' && path == 'hr_employee_profiles') {
          final patch = Map<String, dynamic>.from(jsonDecode(r.body));
          employee.addAll(patch);
          writes.add(patch);
          result = [];
        } else if (path == 'hr_staffing_snapshot') {
          result = {
            'targets': [
              {
                'id': 'target-1',
                'company': 'DICSA CELAYA',
                'position': 'AUXILIAR',
                'required_count': 10,
                'filled_count': employee['employment_status'] == 'baja' ? 7 : 8,
                'revision': 1,
              },
            ],
            'companies': ['DICSA CELAYA'],
            'unassigned_count': 0,
          };
        } else if (path == 'hr_staffing_save_batch') {
          writes.add(Map<String, dynamic>.from(jsonDecode(r.body)));
          if (error != null) {
            return http.Response(
              jsonEncode({'message': 'Injected conflict', 'code': error}),
              409,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          if (loseReply) {
            loseReply = false;
            throw http.ClientException('Lost after commit');
          }
          result = null;
        } else {
          throw StateError('Unexpected request ${r.method} ${r.url}');
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    employee
      ..clear()
      ..addAll({
        'id': 'person-1',
        'nombre': 'PRUEBA',
        'empresa': 'DICSA CELAYA',
        'puesto': 'AUXILIAR',
        'employment_status': 'activo',
        'fecha_ingreso': '2026-01-01',
        'salario': 2000,
      });
    writes.clear();
    loseReply = false;
    error = null;
  });
  testWidgets(
    'real Personal termination and reactivation refresh vacancy badge immediately and retain job/company',
    (tester) async {
      final repository = HrStaffingRepository(Supabase.instance.client);
      final loadErrors = <Object>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AreaThemeScope(
            tokens: humanResourcesAreaTokens,
            child: Scaffold(
              body: HrVacancyPendingButton(
                load: () async {
                  try {
                    return await repository.load();
                  } catch (e) {
                    loadErrors.add(e);
                    rethrow;
                  }
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('vacancyBadge'))).data,
        '2',
      );
      await hrEmploymentStatusForTesting(terminated: true);
      await tester.pumpAndSettle();
      expect(loadErrors, isEmpty);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('vacancyBadge'))).data,
        '3',
      );
      expect(writes.single['employment_status'], 'baja');
      expect(employee['puesto'], 'AUXILIAR');
      expect(employee['empresa'], 'DICSA CELAYA');
      expect(employee['salario'], 2000);
      final date = employee['termination_date'];
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('Faltan 3'), findsOneWidget);
      await hrEmploymentStatusForTesting(terminated: false);
      await tester.pumpAndSettle();
      expect(find.text('Faltan 2'), findsOneWidget);
      expect(writes.last, {'employment_status': 'activo'});
      expect(employee['termination_date'], date);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'repository retries identical batch after unknown reply and unfreezes definitive conflicts',
    () async {
      final repo = HrStaffingRepository(Supabase.instance.client);
      final ops = [
        HrStaffingSave(company: 'KS', position: 'OPERADOR', requiredCount: 10),
      ];
      loseReply = true;
      await expectLater(repo.save(ops), throwsA(isA<http.ClientException>()));
      expect(ops.single.confirmationPending, isTrue);
      await repo.save(ops);
      expect(writes[0], writes[1]);
      expect(ops.single.confirmationPending, isFalse);
      error = '40001';
      await expectLater(repo.save(ops), throwsA(isA<PostgrestException>()));
      expect(ops.single.confirmationPending, isFalse);
    },
  );
}
