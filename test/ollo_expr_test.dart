import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/widgets/entry/ollo_entry_sheet.dart';

void main() {
  test('presedensi: × ÷ dikerjakan sebelum + −', () {
    expect(evalOlloExpr('2+3×4'), 14);
    expect(evalOlloExpr('10-2÷4'), 9.5);
    expect(evalOlloExpr('2×3+4×5'), 26);
    expect(evalOlloExpr('100-20÷5-2'), 94);
  });

  test('desimal, minus unary, dan alias * /', () {
    expect(evalOlloExpr('1.5+2.5'), 4);
    expect(evalOlloExpr('-5+8'), 3);
    expect(evalOlloExpr('10*-2'), -20);
    expect(evalOlloExpr('8/4+2*3'), 8);
    expect(evalOlloExpr('−3+10'), 7);
  });

  test('ekspresi tak valid -> null', () {
    expect(evalOlloExpr(''), isNull);
    expect(evalOlloExpr('5+'), isNull);
    expect(evalOlloExpr('+5'), isNull);
    expect(evalOlloExpr('5/0'), isNull);
    expect(evalOlloExpr('abc'), isNull);
    expect(evalOlloExpr('5++3'), isNull);
    expect(evalOlloExpr('3..5+1'), isNull);
  });
}
