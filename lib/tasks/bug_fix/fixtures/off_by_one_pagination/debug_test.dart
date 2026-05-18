import 'package:off_by_one_pagination/pagination.dart';
void main(){
  var p = Paginator(List<int>.generate(25, (i)=>i));
  print('pageCount=${p.pageCount}');
  print('pages=${p.pageCount}');
  for (int i=0;i<p.pageCount;i++){
    print('page $i: ${p.page(i)}');
  }
}
