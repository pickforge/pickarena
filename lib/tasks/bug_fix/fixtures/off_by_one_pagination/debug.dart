import 'lib/pagination.dart';

void main() {
  final p = Paginator(List<int>.generate(25, (i) => i));
  print('pageCount: ${p.pageCount}');
  print('page(0): ${p.page(0)}');
  print('page(1): ${p.page(1)}');
  print('page(2): ${p.page(2)}');
  
  // Debug the clac
  print('clamp debug:');
  print('10.clamp(0, 25) = ${10.clamp(0, 25)}');
  print('20.clamp(10, 25) = ${20.clamp(10, 25)}');
  print('30.clamp(20, 25) = ${30.clamp(20, 25)}');
  print('(2*10+10).clamp(2*10, 25) = ${(2*10+10).clamp(2*10, 25)}');
}
