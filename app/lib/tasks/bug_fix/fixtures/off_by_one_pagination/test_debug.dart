import 'lib/pagination.dart';

void main() {
  final p = Paginator(List<int>.generate(25, (i) => i));
  print('pageCount: ${p.pageCount}');
  print('page(0): ${p.page(0)}');
  print('page(1): ${p.page(1)}');
  print('page(2): ${p.page(2)}');
}
