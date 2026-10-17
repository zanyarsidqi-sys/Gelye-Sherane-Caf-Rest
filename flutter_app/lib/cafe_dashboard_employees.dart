import 'package:flutter/material.dart';
import 'cafe_language.dart';
import 'cafe_finance_surface.dart';
import 'cafe_operations_workspace.dart';

class CafeDashboardEmployees extends StatefulWidget {
  const CafeDashboardEmployees({super.key,this.rpc});
  final CafeRpc? rpc;
  @override
  State<CafeDashboardEmployees> createState()=>_CafeDashboardEmployeesState();
}
class _CafeDashboardEmployeesState extends State<CafeDashboardEmployees> {
  List<Map<String,dynamic>> _staff=[];
  bool _loading=true;
  String _query='';
  String? _error;
  int _request=0;
  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){_request++;super.dispose();}
  Future<void> _load()async {
    final request=++_request;
    setState((){_staff=[];_loading=true;_error=null;});
    try {
      if(widget.rpc==null)throw StateError('Unavailable');
      final staff=cafeRows(await widget.rpc!('get_cafe_table_staff',{}));
      if(staff.any((r)=>r['id'] is! String || r['name'] is! String)) {
        throw const FormatException('Invalid staff entry');
      }
      staff.sort((a,b)=>(a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      if(mounted&&request==_request)setState(()=>_staff=staff);
    } catch(_) {
      if(mounted&&request==_request)setState(()=>_error='Could not load staff. Check table assignment access and refresh.');
    } finally {
      if(mounted&&request==_request)setState(()=>_loading=false);
    }
  }
  @override
  Widget build(BuildContext context)=>CafeFinanceSurface(builder:(context){
    final rows=_staff.where((r)=>(r['name'] as String).toLowerCase().contains(_query.trim().toLowerCase())).toList();
    return Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const CafeText('Employees',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const CafeText('Staff directory for table assignments. Use employee management for account changes.'),
        Align(alignment:AlignmentDirectional.centerStart,child:OutlinedButton(
          onPressed:_loading?null:_load,child:const CafeText('Refresh'))),
        TextField(decoration:const InputDecoration(label:CafeText('Search staff')),
          onChanged:(value)=>setState(()=>_query=value)),
        if(_loading)const LinearProgressIndicator(),
        if(_error!=null)CafeText(_error!),
        if(!_loading&&_error==null)...[
          CafeText('${rows.length} matching staff · ${_staff.length} loaded'),
          if(rows.isEmpty)const CafeText('No matching staff.'),
          for(final row in rows)Card(child:ListTile(
            leading:const Icon(Icons.person_outline),title:Text(row['name'] as String))),
        ],
      ]));
  });
}
