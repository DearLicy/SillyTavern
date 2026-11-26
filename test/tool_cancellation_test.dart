import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/deepseek_tools.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/platform/pcm_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

class _HangingClient extends http.BaseClient {
  final started = Completer<void>();
  Future<void>? aborted;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    aborted = (request as http.Abortable).abortTrigger;
    if (!started.isCompleted) started.complete();
    await aborted;
    throw http.RequestAbortedException(request.url);
  }
}

class _SlowKeyStore extends FakeKeyStore {
  Completer<void>? release;
  final started = Completer<void>();
  @override
  Future<String?> read({required bool persistent}) async {
    if (release != null) {
      if (!started.isCompleted) started.complete();
      await release!.future;
    }
    return super.read(persistent: persistent);
  }
}

void main() {
  for (final mode in ['caller', 'timeout', 'cancelAll']) {
    test('tool $mode actually aborts its HTTP request', () async {
      final client = _HangingClient();
      final tools = DeepSeekTools(
        client: client,
        requestTimeout: mode == 'timeout'
            ? const Duration(milliseconds: 30)
            : const Duration(seconds: 3),
      );
      addTearDown(tools.close);
      final caller = Completer<void>();
      final request = tools.search(
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'fake-key',
        query: 'test',
        abortTrigger: caller.future,
      );
      // Observe errors before firing cancellation, including under full-suite scheduling.
      final check = expectLater(
        request,
        throwsA(
          isA<AiClientException>().having(
            (e) => e.message,
            'message',
            contains(mode == 'timeout' ? '超时' : '取消'),
          ),
        ),
      );
      await client.started.future;
      if (mode == 'caller') caller.complete();
      if (mode == 'cancelAll') tools.cancelAll();
      await check;
      await client.aborted!.timeout(const Duration(seconds: 1));
    });
  }

  test(
    'reset cancels media operation before an old transcript can return',
    () async {
      final client = _HangingClient();
      final key = FakeKeyStore()..value = 'fake-key';
      final data = buildSeedData();
      final c = AppController(
        store: FakeStore(data),
        keyStore: key,
        toolKeyStore: FakeKeyStore(),
        attachmentStore: MemoryAttachments(),
        tools: DeepSeekTools(client: client),
      );
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      final work = c.transcribeAudio(pcmToWav(Uint8List(3200)));
      final check = expectLater(work, throwsA(isA<AiClientException>()));
      await client.started.future;
      await c.resetData();
      await check;
      await client.aborted;
      expect(c.state.data.messages, isEmpty);
    },
  );

  test('clearing the API key cancels current synthesis', () async {
    final client = _HangingClient();
    final c = AppController(
      store: FakeStore(buildSeedData()),
      keyStore: FakeKeyStore()..value = 'fake-key',
      toolKeyStore: FakeKeyStore(),
      tools: DeepSeekTools(client: client),
    );
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);
    final work = c.synthesizeSpeech('你好');
    final check = expectLater(work, throwsA(isA<AiClientException>()));
    await client.started.future;
    await c.clearProviderKey();
    await check;
    await client.aborted;
    expect(c.state.hasApiKey, isFalse);
  });

  test(
    'tool awaiting a key cannot start using reset or newly switched credentials',
    () async {
      final client = _HangingClient();
      final key = _SlowKeyStore()..value = 'fake-key';
      final c = AppController(
        store: FakeStore(buildSeedData()),
        keyStore: key,
        toolKeyStore: FakeKeyStore(),
        tools: DeepSeekTools(client: client),
      );
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      key.release = Completer<void>();
      final request = c.synthesizeSpeech('你好');
      final check = expectLater(request, throwsA(isA<AiClientException>()));
      await key.started.future;
      await c.clearProviderKey();
      key.release!.complete();
      await check;
      expect(client.started.isCompleted, isFalse);
    },
  );

  test(
    'WAV checks reject truncation, incorrect encodings and excessive duration',
    () {
      final wave = pcmToWav(Uint8List(32000));
      expect(isCompletePcmWav(wave), isTrue);
      expect(
        isCompletePcmWav(Uint8List.sublistView(wave, 0, wave.length - 1)),
        isFalse,
      );
      final wrongType = Uint8List.fromList(wave);
      ByteData.sublistView(wrongType).setUint16(20, 3, Endian.little);
      expect(isCompletePcmWav(wrongType), isFalse);
      expect(
        isCompletePcmWav(wave, maxDuration: const Duration(milliseconds: 500)),
        isFalse,
      );
      final wrongAlign = Uint8List.fromList(wave);
      ByteData.sublistView(wrongAlign).setUint16(32, 0, Endian.little);
      expect(isCompletePcmWav(wrongAlign), isFalse);
      final streamWave = Uint8List.fromList(wave);
      ByteData.sublistView(streamWave)
        ..setUint32(4, 0xffffffff, Endian.little)
        ..setUint32(40, 0xffffffff, Endian.little);
      expect(isCompletePcmWav(streamWave), isTrue);
      expect(
        isCompletePcmWav(
          Uint8List.fromList(utf8.encode('RIFF not real audio')),
        ),
        isFalse,
      );
    },
  );
}
