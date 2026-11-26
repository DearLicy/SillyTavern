import 'dart:convert';
import 'dart:typed_data';

/// Reads SillyTavern PNG character-card metadata from tEXt/iTXt chunks.
/// This parser is intentionally bounded and never executes card content.
class PngCharacterCard {
  const PngCharacterCard();

  static const _signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  String extractJson(Uint8List bytes) {
    if (bytes.length < 8 + 12 || bytes.length > 32 * 1024 * 1024) {
      throw const FormatException('PNG 角色卡为空或过大');
    }
    for (var i = 0; i < _signature.length; i++) {
      if (bytes[i] != _signature[i]) {
        throw const FormatException('不是有效的 PNG 文件');
      }
    }
    var offset = 8;
    final data = ByteData.sublistView(bytes);
    while (offset + 12 <= bytes.length) {
      final length = data.getUint32(offset, Endian.big);
      if (length > 16 * 1024 * 1024 || offset + 12 + length > bytes.length) {
        throw const FormatException('PNG 数据块损坏或过大');
      }
      final type = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: false,
      );
      final chunk = bytes.sublist(offset + 8, offset + 8 + length);
      if (type == 'tEXt') {
        final card = _fromText(chunk);
        if (card != null) return card;
      } else if (type == 'iTXt') {
        final card = _fromInternationalText(chunk);
        if (card != null) return card;
      }
      offset += 12 + length;
      if (type == 'IEND') break;
    }
    throw const FormatException('PNG 中没有 SillyTavern 角色卡元数据');
  }

  String? _fromText(Uint8List chunk) {
    final separator = chunk.indexOf(0);
    if (separator <= 0 || separator >= chunk.length - 1) return null;
    final keyword = ascii.decode(
      chunk.sublist(0, separator),
      allowInvalid: false,
    );
    if (keyword != 'ccv3' && keyword != 'chara') return null;
    return _decodeCardText(chunk.sublist(separator + 1));
  }

  String? _fromInternationalText(Uint8List chunk) {
    var index = chunk.indexOf(0);
    if (index <= 0) return null;
    final keyword = ascii.decode(chunk.sublist(0, index), allowInvalid: false);
    if (keyword != 'ccv3' && keyword != 'chara') return null;
    index++;
    if (index + 2 > chunk.length) return null;
    final compressed = chunk[index] == 1;
    index += 2;
    final languageEnd = chunk.indexOf(0, index);
    if (languageEnd < 0) return null;
    index = languageEnd + 1;
    final translatedEnd = chunk.indexOf(0, index);
    if (translatedEnd < 0) return null;
    index = translatedEnd + 1;
    if (compressed) {
      throw const FormatException('暂不支持压缩的 PNG 角色卡元数据');
    }
    return _decodeCardText(chunk.sublist(index));
  }

  String _decodeCardText(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw const FormatException('PNG 角色卡元数据为空或过大');
    }
    try {
      final text = utf8.decode(bytes, allowMalformed: false).trim();
      final json = utf8.decode(base64Decode(text), allowMalformed: false);
      if (!json.trimLeft().startsWith('{')) {
        throw const FormatException('角色卡元数据不是 JSON 对象');
      }
      return json;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('PNG 角色卡元数据不是有效 Base64 JSON');
    }
  }
}
