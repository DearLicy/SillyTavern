import 'package:sillytavern_app/domain/dialogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chinese and ASCII actions leave the speech bubbles in order', () {
    final parts = DialogueParser.parse('（脚步停住）不脱。（转身）我说话不好听。 (走远了)');
    expect(parts.map((e) => e.text), ['脚步停住', '不脱。', '转身', '我说话不好听。', '走远了']);
    expect(parts.map((e) => e.kind), [
      DialogueSegmentKind.narration,
      DialogueSegmentKind.speech,
      DialogueSegmentKind.narration,
      DialogueSegmentKind.speech,
      DialogueSegmentKind.narration,
    ]);
  });
  test('nested and streaming unfinished actions remain narration', () {
    expect(DialogueParser.parse('（回头（停顿），看着你）').single.text, '回头（停顿），看着你');
    final partial = DialogueParser.parse('你好（轻轻抬手');
    expect(partial.last.text, '轻轻抬手');
    expect(partial.last.kind, DialogueSegmentKind.narration);
  });
  test('thoughts, machine data and structural leftovers make no bubbles', () {
    expect(
      DialogueParser.parse('<think>分析</think>```stats\n{"x":1}\n```\n（）\n```'),
      isEmpty,
    );
    expect(DialogueParser.parse('（ ）\u200B'), isEmpty);
  });
  test('V1 italic and quoted narration works beside spoken dialogue', () {
    final parts = DialogueParser.parse('*你听见脚步声*\n“等我（一下）。”\n> 夜色渐深');
    expect(parts.map((e) => e.text), ['你听见脚步声', '等我（一下）。', '夜色渐深']);
    expect(parts[1].kind, DialogueSegmentKind.speech);
  });
}
