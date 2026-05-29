import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_exception.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_client.dart';

void main() {
  const baseUrl = 'http://192.168.43.1:8080';

  // ─── authenticate ─────────────────────────────────────────────────────────────

  group('authenticate', () {
    test('returns token on valid PIN', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        client: MockClient((req) async {
          expect(req.url.path, '/auth');
          expect(jsonDecode(req.body)['pin'], '123456');
          return http.Response('{"token":"abc123"}', 200);
        }),
      );
      expect(await client.authenticate('123456'), 'abc123');
    });

    test('throws SyncAuthException on 401', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        client: MockClient((_) async =>
            http.Response('{"error":"invalid_pin"}', 401)),
      );
      expect(
        () => client.authenticate('wrong'),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('does NOT retry on auth failure', () async {
      int callCount = 0;
      final client = SyncClient(
        baseUrl: baseUrl,
        client: MockClient((_) async {
          callCount++;
          return http.Response('{"error":"invalid_pin"}', 401);
        }),
      );
      await expectLater(
        () => client.authenticate('x'),
        throwsA(isA<SyncAuthException>()),
      );
      expect(callCount, 1); // no retry
    });

    test('throws SyncNetworkException on SocketException', () async {
      final client = SyncClient(
        baseUrl: 'http://0.0.0.0:9999',
        client: MockClient(
            (_) async => throw http.ClientException('Connection refused')),
      );
      expect(
        () => client.authenticate('123456'),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });

  // ─── get ──────────────────────────────────────────────────────────────────────

  group('get', () {
    test('returns parsed JSON on 200', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'mytoken',
        client: MockClient((req) async {
          expect(req.headers['authorization'], 'Bearer mytoken');
          return http.Response('{"role":"control"}', 200);
        }),
      );
      final result = await client.get('/status');
      expect(result['role'], 'control');
    });

    test('throws SyncAuthException on 401', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'expired',
        client: MockClient(
            (_) async => http.Response('{"error":"invalid_token"}', 401)),
      );
      expect(
        () => client.get('/status'),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('throws SyncServerException on 503', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'tok',
        client: MockClient(
            (_) async => http.Response('{"error":"down"}', 503)),
      );
      Object? caughtError;
      try {
        await client.get('/status');
      } catch (e) {
        caughtError = e;
      }
      expect(caughtError, isA<SyncServerException>());
      expect((caughtError! as SyncServerException).statusCode, 503);
    });

    test('retries once on ClientException and succeeds on second attempt',
        () async {
      int callCount = 0;
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'tok',
        client: MockClient((req) async {
          callCount++;
          if (callCount == 1) {
            throw http.ClientException('transient error');
          }
          return http.Response('{"ok":true}', 200);
        }),
      );
      final result = await client.get('/status');
      expect(callCount, 2);
      expect(result['ok'], isTrue);
    });

    test('throws SyncNetworkException after exhausting retries', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'tok',
        client: MockClient((_) async =>
            throw http.ClientException('persistent error')),
      );
      expect(
        () => client.get('/status'),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });

  // ─── post ─────────────────────────────────────────────────────────────────────

  group('post', () {
    test('sends JSON body and returns parsed response', () async {
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'tok',
        client: MockClient((req) async {
          expect(req.method, 'POST');
          expect(jsonDecode(req.body)['key'], 'value');
          return http.Response('{"merged":3}', 200);
        }),
      );
      final result = await client.post('/sales/push', {'key': 'value'});
      expect(result['merged'], 3);
    });

    test('retries once on ClientException', () async {
      int callCount = 0;
      final client = SyncClient(
        baseUrl: baseUrl,
        token: 'tok',
        client: MockClient((req) async {
          callCount++;
          if (callCount == 1) throw http.ClientException('transient');
          return http.Response('{"ok":true}', 200);
        }),
      );
      await client.post('/sales/push', {});
      expect(callCount, 2);
    });
  });
}
