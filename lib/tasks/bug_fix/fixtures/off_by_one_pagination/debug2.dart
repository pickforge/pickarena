import 'lib/pagination.dart';

void main() {
  print('Testing pageCount:');
  print('(25 + 10 - 1) ~/ 10 = ${(25 + 10 - 1) ~/ 10}');

  final p = Paginator(List<int>.generate(25, (i) => i));
  print('pageCount: ${p.pageCount}');
  print('page(0): ${p.page(0)}');
  print('page(0).length: ${p.page(0).length}');
  print('page(1): ${p.page(1)}');
  print('page(1).length: ${p.page(1).length}');
  print('page(2): ${p.page(2)}');
  print('page(2).length: ${p.page(2).length}');

  // Debug the clamp logic
  print('\nDebug:');
  int start = 20;
  int end = (start + 10).clamp(start, 25);
  print(
    'start=$start, (start+10)=${start + 10}, clamp(start, 25)=${end}, sublist=$end',
  );
  print('Expected: sublist(20, 25) gives indices 20,21,22,23,24 (5 items)');
}
