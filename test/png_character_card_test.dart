import 'dart:convert';
import 'dart:typed_data';

import 'package:sillytavern_app/data/png_character_card.dart';
import 'package:flutter_test/flutter_test.dart';

const _json =
    '{"spec":"chara_card_v2","data":{"name":"知夏","first_mes":"进来避雨吗？"}}';

void main() {
  const parser = PngCharacterCard();

  Uint8List chunk(String type, List<int> data) {
    final bytes = BytesBuilder();
    final length = ByteData(4)..setUint32(0, data.length, Endian.big);
    bytes.add(length.buffer.asUint8List());
    bytes.add(ascii.encode(type));
    bytes.add(data);
    bytes.add(Uint8List(4));
    return bytes.takeBytes();
  }

  Uint8List pngWithText(String keyword) {
    final payload = [
      ...ascii.encode(keyword),
      0,
      ...utf8.encode(base64Encode(utf8.encode(_json))),
    ];
    return Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ...chunk('tEXt', payload),
      ...chunk('IEND', const []),
    ]);
  }

  test('extracts ccv3 and chara tEXt metadata', () {
    expect(parser.extractJson(pngWithText('ccv3')), _json);
    expect(parser.extractJson(pngWithText('chara')), _json);
  });

  test('reads uncompressed iTXt metadata', () {
    final payload = [
      ...ascii.encode('ccv3'),
      0,
      0,
      0,
      0,
      0,
      ...utf8.encode(base64Encode(utf8.encode(_json))),
    ];
    final png = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ...chunk('iTXt', payload),
      ...chunk('IEND', const []),
    ]);
    expect(parser.extractJson(png), _json);
  });

  test('rejects non-PNG and missing card metadata', () {
    expect(
      () => parser.extractJson(Uint8List.fromList(const [1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
    final png = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ...chunk('IEND', const []),
    ]);
    expect(() => parser.extractJson(png), throwsA(isA<FormatException>()));
  });
}
