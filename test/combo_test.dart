import 'package:flutter_3_player_poker/game/combo.dart';
import 'package:flutter_3_player_poker/game/combo_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('牌型识别', () {
    test('王炸与炸弹', () {
      expect(detectCombo(handOf('16 17'))!.type, ComboType.rocket);
      expect(detectCombo(handOf('9 9 9 9'))!.type, ComboType.bomb);
    });

    test('基础牌型', () {
      expect(detectCombo(handOf('3'))!.type, ComboType.single);
      expect(detectCombo(handOf('8 8'))!.type, ComboType.pair);
      expect(detectCombo(handOf('8 8 8'))!.type, ComboType.triple);
      expect(detectCombo(handOf('8 8 8 4'))!.type, ComboType.tripleSingle);
      expect(detectCombo(handOf('8 8 8 4 4'))!.type, ComboType.triplePair);
    });

    test('三带一不能带两张不同单牌', () {
      expect(detectCombo(handOf('8 8 8 4 5')), isNull);
      expect(detectCombo(handOf('8 8 8 8 3')), isNull);
    });

    test('顺子', () {
      final straight = detectCombo(handOf('3 4 5 6 7'))!;
      expect(straight.type, ComboType.straight);
      expect(straight.rank, 7);
      expect(straight.length, 5);
      expect(detectCombo(handOf('10 11 12 13 14'))!.type, ComboType.straight);
      expect(detectCombo(handOf('11 12 13 14 15')), isNull);
      expect(detectCombo(handOf('16 17 3 4 5')), isNull);
      expect(detectCombo(handOf('3 4 5 6')), isNull);
      expect(detectCombo(handOf('3 3 4 5 6')), isNull);
    });

    test('连对', () {
      expect(detectCombo(handOf('3 3 4 4 5 5'))!.type, ComboType.straightPair);
      expect(detectCombo(handOf('13 13 14 14 15 15')), isNull);
      expect(detectCombo(handOf('3 3 4 4')), isNull);
    });

    test('飞机与翅膀', () {
      final plane = detectCombo(handOf('3 3 3 4 4 4'))!;
      expect(plane.type, ComboType.plane);
      expect(plane.length, 2);
      expect(
        detectCombo(handOf('3 3 3 4 4 4 5 5'))!.type,
        ComboType.planeSingle,
      );
      expect(
        detectCombo(handOf('3 3 3 4 4 4 5 5 6 6'))!.type,
        ComboType.planePair,
      );
      expect(detectCombo(handOf('3 3 3 5 5 5')), isNull);
      expect(detectCombo(handOf('3 3 3 4 4 4 3 5')), isNull);
    });

    test('四带二', () {
      expect(detectCombo(handOf('8 8 8 8 3 4'))!.type, ComboType.fourTwoSingle);
      expect(
        detectCombo(handOf('8 8 8 8 3 3 4 4'))!.type,
        ComboType.fourTwoPair,
      );
      expect(detectCombo(handOf('8 8 8 8 3 3 4')), isNull);
    });

    test('空牌与重复非法组合', () {
      expect(detectCombo([]), isNull);
      expect(detectCombo(handOf('3 4')), isNull);
      expect(detectCombo(handOf('3 3 4')), isNull);
    });
  });

  group('大小比较', () {
    test('同牌型比点数', () {
      final five = detectCombo(handOf('5'))!;
      final six = detectCombo(handOf('6'))!;
      expect(beatsCombo(six, five), isTrue);
      expect(beatsCombo(five, six), isFalse);
      expect(beatsCombo(five, five), isFalse);
    });

    test('牌型与长度必须一致', () {
      final pair = detectCombo(handOf('9 9'))!;
      final single = detectCombo(handOf('10'))!;
      expect(beatsCombo(single, pair), isFalse);

      final shortStraight = detectCombo(handOf('3 4 5 6 7'))!;
      final longStraight = detectCombo(handOf('4 5 6 7 8 9'))!;
      expect(beatsCombo(longStraight, shortStraight), isFalse);

      final biggerShort = detectCombo(handOf('4 5 6 7 8'))!;
      expect(beatsCombo(biggerShort, shortStraight), isTrue);
    });

    test('炸弹与王炸压制关系', () {
      final bomb3 = detectCombo(handOf('3 3 3 3'))!;
      final bomb4 = detectCombo(handOf('4 4 4 4'))!;
      final rocket = detectCombo(handOf('16 17'))!;
      final plane = detectCombo(handOf('3 3 3 4 4 4'))!;

      expect(beatsCombo(bomb3, plane), isTrue);
      expect(beatsCombo(bomb3, bomb4), isFalse);
      expect(beatsCombo(bomb4, bomb3), isTrue);
      expect(beatsCombo(rocket, bomb4), isTrue);
      expect(beatsCombo(bomb4, rocket), isFalse);
      expect(beatsCombo(plane, bomb4), isFalse);
    });
  });
}
