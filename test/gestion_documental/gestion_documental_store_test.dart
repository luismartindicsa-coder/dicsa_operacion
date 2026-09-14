import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_record_draft.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_store.dart';

const uid = '00000000-0000-4000-8000-000000000001';
DocumentalRecordDraft draft() => DocumentalRecordDraft()
  ..title = 'Acta'
  ..documentType = 'Acta constitutiva'
  ..responsibleId = uid
  ..status = 'Pendiente'
  ..priority = 'Media'
  ..principal = PlatformFile(
    name: 'acta.pdf',
    size: 3,
    bytes: Uint8List.fromList([1, 2, 3]),
  );

Future<SupabaseClient> clientFor(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = SupabaseClient(
    'https://documental-test.invalid',
    'test-only-key',
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response(
        response.body,
        response.statusCode,
        request: request,
        headers: {'content-type': 'application/json', ...response.headers},
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'refresh_token': 'test-refresh',
      'user': {
        'id': uid,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  test(
    'an uncertain save retries the same request and never reuploads or deletes its files',
    () async {
      final calls = <http.Request>[];
      var rpcCount = 0;
      final client = await clientFor((req) async {
        calls.add(req);
        if (req.url.path.contains('/storage/v1/object/')) {
          return http.Response(jsonEncode({'Key': req.url.path}), 200);
        }
        if (req.url.path.endsWith('/rpc/documental_save_record')) {
          rpcCount++;
          if (rpcCount == 1) throw StateError('Response lost after commit');
          final data = jsonDecode(req.body) as Map;
          return http.Response(
            jsonEncode({
              'record': {
                ...data['p_record'],
                'id': data['p_id'],
                'revision': 1,
              },
              'files': [],
              'history': [],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final store = SupabaseDocumentalStore(client);
      final operation = DocumentalSaveOperation(draft());
      await expectLater(store.save(operation), throwsStateError);
      expect(operation.confirmationPending, isTrue);
      await store.save(operation);
      final rpcs = calls
          .where((r) => r.url.path.endsWith('/rpc/documental_save_record'))
          .toList();
      expect(rpcs.length, 2);
      expect(rpcs[0].body, rpcs[1].body);
      expect(
        calls
            .where(
              (r) => r.url.path.contains('/storage/') && r.method == 'POST',
            )
            .length,
        1,
      );
      expect(calls.where((r) => r.method == 'DELETE'), isEmpty);
      expect(operation.confirmationPending, isFalse);
    },
  );

  test(
    'a confirmed SQL failure cleans only this operation staged uploads',
    () async {
      final calls = <http.Request>[];
      final client = await clientFor((req) async {
        calls.add(req);
        if (req.method == 'DELETE') return http.Response('[]', 200);
        if (req.url.path.contains('/storage/')) {
          return http.Response(jsonEncode({'Key': req.url.path}), 200);
        }
        return http.Response(
          jsonEncode({
            'code': 'PT409',
            'message': 'El expediente cambió',
            'details': null,
            'hint': null,
          }),
          400,
        );
      });
      final op = DocumentalSaveOperation(draft());
      await expectLater(
        SupabaseDocumentalStore(client).save(op),
        throwsA(isA<PostgrestException>()),
      );
      expect(op.confirmationPending, isFalse);
      expect(op.uploaded, isEmpty);
      final cleanup =
          jsonDecode(calls.singleWhere((r) => r.method == 'DELETE').body)
              as Map;
      expect(
        (cleanup['prefixes'] as List).single,
        startsWith('$uid/${op.id}/'),
      );
    },
  );
}
