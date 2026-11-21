import 'dart:convert';

/// JSON payloads from OpenAI-compatible SSE, JSONL, or mislabeled JSON bodies.
/// Incremental UTF-8 decoding keeps characters intact across network chunks.
/// Accept one-line events without blank separators used by several relays,
/// while joining data lines for actual multiline SSE events.
Stream<Map<String, dynamic>> decodeOpenAiFrames(
  Stream<List<int>> source,
) async* {
  var pending = '';
  String? event;
  await for (final line
      in source.transform(utf8.decoder).transform(const LineSplitter())) {
    final text = line.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (text.isEmpty) {
      pending = '';
      event = null;
      continue;
    }
    if (text.startsWith(':') ||
        text.startsWith('id:') ||
        text.startsWith('retry:')) {
      continue;
    }
    if (text.startsWith('event:')) {
      event = text.substring(6).trim();
      continue;
    }
    final payload = text.startsWith('data:')
        ? text.substring(5).trimLeft()
        : text;
    if (payload == '[DONE]') return;
    if (pending.isEmpty && !payload.startsWith('{')) continue;
    pending = pending.isEmpty ? payload : '$pending\n$payload';
    if (pending.length > 8 * 1024 * 1024) {
      throw const FormatException('供应商单个响应片段过大');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(pending);
    } on FormatException {
      // A split JSON document continues on the next data line. Parsing failures
      // are the only errors handled here; API errors and UI callbacks propagate.
      continue;
    }
    pending = '';
    if (decoded is Map<String, dynamic>) {
      yield {
        ...decoded,
        if (event == 'error' && decoded['type'] == null) 'type': 'error',
      };
    }
  }
}
