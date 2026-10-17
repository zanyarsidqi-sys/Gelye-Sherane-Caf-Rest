
import 'package:flutter/material.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operational_report.dart';
import 'cafe_operations_workspace.dart';

class CafeReportLibrary extends StatefulWidget {
  const CafeReportLibrary({super.key,required this.allowed,this.rpc});
  final Set<String> allowed;
  final CafeRpc? rpc;
  @override
  State<CafeReportLibrary> createState()=>_CafeReportLibraryState();
}
class _CafeReportLibraryState extends State<CafeReportLibrary> {
  String _query='';
  String? _selected;
  Set<String> get _reports=>widget.allowed.intersection(operationalReportCards['dashboard']!);
  @override
  void didUpdateWidget(CafeReportLibrary oldWidget){
    super.didUpdateWidget(oldWidget);
    if(!_reports.contains(_selected))_selected=null;
  }
  @override
  Widget build(BuildContext context){
    final selected=_selected;
    final titles=_reports.where((title)=>title.toLowerCase().contains(_query.trim().toLowerCase())).toList()..sort();
    return CafeFinanceSurface(builder:(context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const CafeText('Reports',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const CafeText('Open an authorized Dashboard report. Choose dates, search, filter and export inside each report.'),
      if(selected!=null)...[
        Align(alignment:AlignmentDirectional.centerStart,child:TextButton.icon(
          onPressed:()=>setState(()=>_selected=null),icon:const Icon(Icons.arrow_back),
          label:const CafeText('All reports'))),
        CafeOperationalReport(key:ValueKey(selected),section:'dashboard',
          card:selected.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_').replaceAll(RegExp(r'^_|_$'),''),
          title:selected,rpc:widget.rpc),
      ]else...[
        TextField(onChanged:(value)=>setState(()=>_query=value),
          decoration:const InputDecoration(labelText:'Search reports',prefixIcon:Icon(Icons.search))),
        if(_reports.isEmpty)const CafeText('No Dashboard report permissions have been assigned.'),
        if(_reports.isNotEmpty&&titles.isEmpty)const CafeText('No matching reports.'),
        for(final title in titles)Card(child:ListTile(
          title:CafeText(title),trailing:const Icon(Icons.chevron_right),
          onTap:()=>setState(()=>_selected=title))),
      ],
    ]));
  }
}
