import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/image_content.dart';
import '../platform/pcm_audio.dart';
import '../domain/search_source.dart';
export '../domain/search_source.dart';
import 'ai_client.dart';

class OcrResult {
  const OcrResult(this.text, {required this.incomplete});
  final String text;
  final bool incomplete;
}

/// Official, documented endpoints. No account cookies or undocumented Chat
/// website calls; no credentials are copied to a hardcoded third-party host.
class DeepSeekTools {
  DeepSeekTools({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 90),
    this.ocrTimeout = const Duration(seconds: 190),
  }) : _client = client ?? http.Client();
  final Duration requestTimeout;
  final Duration ocrTimeout;
  final Set<Completer<void>> _active = {};
  bool _closed = false;

  /// Cancels network I/O as well as discarding its result. A timeout must not
  /// leave a paid request silently running in the client after the UI retries.
  Future<T> _run<T>(
    Future<void>? callerAbort,
    Future<T> Function(Future<void> abort) operation, {
    Duration? timeout,
  }) async {
    if (_closed) throw const AiClientException('工具连接已关闭。');
    final abort = Completer<void>();
    _active.add(abort);
    var expired = false;
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    callerAbort?.then(
      (_) => cancel(),
      onError: (Object _, StackTrace __) => cancel(),
    );
    final timer = Timer(timeout ?? requestTimeout, () {
      expired = true;
      cancel();
    });
    try {
      await Future<void>.value();
      if (abort.isCompleted) throw const AiClientException('操作已取消。');
      return await Future.any<T>([
        operation(abort.future),
        abort.future.then<T>(
          (_) => throw AiClientException(expired ? '工具响应超时，请稍后重试。' : '操作已取消。'),
        ),
      ]);
    } catch (_) {
      if (abort.isCompleted) {
        throw AiClientException(expired ? '工具响应超时，请稍后重试。' : '操作已取消。');
      }
      rethrow;
    } finally {
      timer.cancel();
      _active.remove(abort);
    }
  }

  void cancelAll() {
    for (final abort in _active) {
      if (!abort.isCompleted) abort.complete();
    }
  }

  final http.Client _client;

  Uri _uri(String baseUrl, String tool) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        base.host.toLowerCase() != 'api.deepseek.com' ||
        base.scheme != 'https' ||
        base.userInfo.isNotEmpty ||
        base.hasPort) {
      throw const AiClientException(
        '搜索、OCR 和语音工具使用 DeepSeek 官方 API，请在设置的「搜索与语音」中配置官方密钥。',
      );
    }
    return Uri.https('api.deepseek.com', '/v1/tools/$tool');
  }

  Map<String, String> _headers(String key) {
    if (key.trim().isEmpty) throw const AiClientException('请先配置 API Key');
    return {
      'Authorization': 'Bearer ${key.trim()}',
      'Accept': 'application/json',
    };
  }

  Future<http.Response> _send(
    http.BaseRequest request, {
    int maxBytes = 16 * 1024 * 1024,
  }) async {
    try {
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.stream.take(1).drain<void>();
          throw AiClientException(switch (response.statusCode) {
            401 || 403 => '工具请求没有通过鉴权，请检查密钥及接口权限。',
            400 => '工具未接受本次输入，请检查文件格式或内容。',
            413 => '文件过大，请换一个较小的文件。',
            429 => '工具请求过于频繁，请稍后重试。',
            _ => '工具暂时不可用（HTTP ${response.statusCode}），请重试。',
          });
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const AiClientException('工具返回数据过大，请缩短输入后重试。');
          }
          bytes.add(chunk);
        }
        return http.Response.bytes(
          bytes.takeBytes(),
          response.statusCode,
          headers: response.headers,
        );
      })();
    } on AiClientException {
      rethrow;
    } on TimeoutException {
      throw const AiClientException('工具响应超时，请稍后重试。');
    } catch (_) {
      throw const AiClientException('工具连接失败，请检查网络及浏览器 CORS 设置后重试。');
    }
  }

  Map<String, dynamic> _json(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) return body;
    } catch (_) {
      /* Do not reflect upstream content or credentials. */
    }
    throw const AiClientException('工具返回格式不正确，请重试。');
  }

  Future<List<SearchSource>> search({
    required String baseUrl,
    required String apiKey,
    required String query,
    Future<void>? abortTrigger,
  }) async {
    return _run(abortTrigger, (signal) async {
      if (query.trim().isEmpty || query.runes.length > 128) {
        throw const AiClientException('搜索词应为 1–128 个字符。');
      }
      final request =
          http.AbortableRequest(
              'POST',
              _uri(baseUrl, 'search'),
              abortTrigger: signal,
            )
            ..headers.addAll({
              ..._headers(apiKey),
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'query': query.trim(),
              'count': 5,
              'need_content': false,
            });
      final body = _json(await _send(request));
      if (body['results'] is! List) {
        throw const AiClientException('搜索没有返回可用的结果格式。');
      }
      return [
        for (final row in (body['results'] as List).whereType<Map>())
          if (Uri.tryParse('${row['url']}') case final uri?
              when ['http', 'https'].contains(uri.scheme) &&
                  uri.host.isNotEmpty &&
                  uri.userInfo.isEmpty)
            SearchSource(
              title: '${row['title'] ?? uri.host}',
              url: uri.toString(),
              summary: '${row['summary'] ?? row['snippet'] ?? ''}',
            ),
      ].take(5).toList();
    });
  }

  Future<OcrResult> recognize({
    required String baseUrl,
    required String apiKey,
    required ImageContent image,
    Future<void>? abortTrigger,
  }) async {
    return _run(abortTrigger, (signal) async {
      final request =
          http.AbortableMultipartRequest(
              'POST',
              _uri(baseUrl, 'ocr'),
              abortTrigger: signal,
            )
            ..headers.addAll(_headers(apiKey))
            ..fields['purpose'] = 'text_recognition'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                image.bytes,
                filename: 'image.${image.extension}',
              ),
            );
      final body = _json(await _send(request));
      if (body['pages'] is! List) {
        throw const AiClientException('OCR 没有返回可用页面。');
      }
      final pages = (body['pages'] as List).whereType<Map>().toList();
      pages.sort(
        (a, b) => ((a['index'] as num?)?.toInt() ?? 0).compareTo(
          (b['index'] as num?)?.toInt() ?? 0,
        ),
      );
      final text = pages
          .map(
            (p) => '${p['text'] ?? ''}'
                .replaceAll(RegExp(r'<[｜|]box[｜|]>[\s\S]*?<[｜|]/box[｜|]>'), '')
                .replaceAll(RegExp(r'<[^>]*[｜|][^>]*>'), '')
                .trim(),
          )
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      return OcrResult(
        text,
        incomplete: pages.any((p) => p['finish_reason'] == 'length'),
      );
    }, timeout: ocrTimeout);
  }

  Future<String> transcribe({
    required String baseUrl,
    required String apiKey,
    required Uint8List audio,
    Future<void>? abortTrigger,
  }) async {
    return _run(abortTrigger, (signal) async {
      if (audio.length > 8 * 1024 * 1024 ||
          !isCompletePcmWav(audio, maxDuration: const Duration(seconds: 120))) {
        throw const AiClientException('录音必须为不超过 8 MB 的 PCM WAV。');
      }
      final request =
          http.AbortableMultipartRequest(
              'POST',
              _uri(baseUrl, 'asr'),
              abortTrigger: signal,
            )
            ..headers.addAll(_headers(apiKey))
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                audio,
                filename: 'recording.wav',
              ),
            );
      final body = _json(await _send(request));
      if (body['text'] is! String || (body['text'] as String).trim().isEmpty) {
        throw const AiClientException('没有识别到语音，请重新录制。');
      }
      return (body['text'] as String).trim();
    });
  }

  Future<Uint8List> synthesize({
    required String baseUrl,
    required String apiKey,
    required String text,
    String voice = 'stella',
    Future<void>? abortTrigger,
  }) async {
    return _run(abortTrigger, (signal) async {
      if (text.trim().isEmpty || text.runes.length > 5000) {
        throw const AiClientException('朗读文本为空或过长，请选择较短的消息。');
      }
      if (!['stella', 'tide'].contains(voice)) {
        throw const AiClientException('请选择受支持的声线。');
      }
      final request =
          http.AbortableRequest(
              'POST',
              _uri(baseUrl, 'tts'),
              abortTrigger: signal,
            )
            ..headers.addAll({
              ..._headers(apiKey),
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'text': text.trim(),
              'voice_id': voice,
              'format': 'wav',
              'filter_markdown': true,
            });
      final response = await _send(request, maxBytes: 48 * 1024 * 1024);
      final bytes = response.bodyBytes;
      if (!isCompletePcmWav(bytes)) {
        throw const AiClientException('语音合成未返回完整音频，请重试。');
      }
      return bytes;
    });
  }

  void close() {
    _closed = true;
    cancelAll();
    _client.close();
  }
}
