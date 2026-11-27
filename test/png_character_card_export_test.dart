import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/data/png_character_card.dart';

import 'fixtures/fake_store.dart';

void main() {
  const reader = PngCharacterCard();
  const json =
      '{"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"测试角色"}}';

  test('encodePng writes readable ccv3 metadata', () {
    final png = PngCharacterCard.encodePng(json);
    expect(reader.extractJson(png), json);
  });

  test('embedJson keeps avatar pixels and replaces card metadata', () {
    final embedded = PngCharacterCard.embedJson(MemoryAttachments.pixel, json);
    expect(embedded, isNotNull);
    expect(reader.extractJson(embedded!), json);
    expect(embedded.length, greaterThan(MemoryAttachments.pixel.length));
  });

  test('embedJson rejects non-PNG input', () {
    final notPng = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(PngCharacterCard.embedJson(notPng, json), isNull);
  });
}
