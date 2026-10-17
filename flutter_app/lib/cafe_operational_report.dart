import 'cafe_language.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'cafe_operations_workspace.dart';

const operationalReportCards = <String, Set<String>>{
  'dashboard': {'Today Revenue', 'Cash Received', 'Daily Financial Summary', 'Cash & Payment Methods', 'Sales Performance', 'Pending Payment', 'Refunds & Adjustments', 'Today’s Orders', 'Today Orders', 'Kitchen Orders', 'Motel Orders', 'Online & Walk-In Orders', 'Orders Preparing', 'Ready for Delivery', 'Delayed Orders', 'Table Orders', 'Motel Orders Tracking', 'Online Orders Tracking', 'Walk-In Orders Tracking', 'Online Orders', 'Kitchen Queue', 'Today’s Customers', 'Guests Today', 'Table Occupancy Reports', 'Table Occupancy', 'Product Performance', 'Audit & Activity History', 'Audit & Activity'},
  'payment_management': {'Today Revenue', 'Revenue', 'Payment Overview', 'Collected Cash', 'Table Income', 'Pending Payments', 'Pending Payment', 'Refunds', 'Audit'},
  'motel_online_orders': {'Motel & Online Orders Overview', 'Order Tracking', 'Order History', 'Order Details', 'Room Orders', 'Ready for Pickup', 'Walk-In Order History'},
  'customer_management': {'Kitchen Overview', 'Kitchen Reports', 'Kitchen Performance & Timing', 'Kitchen Priority & Delays'},
  'tables_orders': {'Table Reports'},
  'kitchen_management': {'Product Sales & Performance', 'Menu Reports', 'Price Change History', 'Menu Audit History', 'Revisions'},
};

class CafeOperationalReport extends StatefulWidget {
  const CafeOperationalReport({super.key, required this.section, required this.card, required this.title, this.rpc});
  final String section, card, title;
  final CafeRpc? rpc;
  @override
  State<CafeOperationalReport> createState() => _CafeOperationalReportState();
}
class _CafeOperationalReportState extends State<CafeOperationalReport> {
  late DateTime _from, _to;
  Map<String,dynamic>? _report;
  bool _loading = true;
  String? _error;
  String _query = '';
  @override
  void initState() { super.initState(); final now = DateTime.now().toUtc().add(const Duration(hours:3)); _from = _to = DateTime(now.year,now.month,now.day); _load(); }
  String _date(DateTime value) => value.toIso8601String().substring(0,10);
  Future<void> _load() async {
    setState(() {_loading=true;_error=null;});
    try {
      if (widget.rpc == null) throw StateError('Connection unavailable');
      final result=await widget.rpc!('get_cafe_operational_report',{'p_section':widget.section,'p_card':widget.card,'p_from':_date(_from),'p_to':_date(_to)});
      if(mounted)setState(()=>_report=Map<String,dynamic>.from(result));
    } catch (_) { if(mounted)setState(()=>_error='Could not load the report. Check connection, date range and assigned permission.'); }
    finally { if(mounted)setState(()=>_loading=false); }
  }
  Future<void> _range() async {
    final picked=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDateRange:DateTimeRange(start:_from,end:_to));
    if(picked==null || !mounted)return;
    if(picked.end.difference(picked.start).inDays>366){setState(()=>_error='Choose a date range up to one year.');return;}
    setState((){_from=picked.start;_to=picked.end;});
    await _load();
  }
  Future<void> _print() async {
    final report = _report;
    if (report == null || _error != null || _loading) return;
    try {
      final document=pw.Document();
      document.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4.landscape,build:(_)=>[
        pw.Header(level:0,text:widget.title),
        pw.Text('${_date(_from)} to ${_date(_to)} · Baghdad'),
        pw.SizedBox(height:10),
        pw.Text('${report['note']}'),
        pw.SizedBox(height:10),
        pw.TableHelper.fromTextArray(headers:(report['columns'] as List).map((e)=>'$e').toList(),data:(report['rows'] as List).map((row)=>(row as List).map((e)=>e==null?'—':'$e').toList()).toList(),cellStyle:const pw.TextStyle(fontSize:8)),
      ]));
      await Printing.layoutPdf(name:'${widget.card}-${_date(_from)}.pdf',onLayout:(_) => document.save());
    } catch (_) { if(mounted)setState(()=>_error='Could not prepare the report for printing. Refresh and try again.'); }
  }
  @override
  Widget build(BuildContext context) {
    final columns=(_report?['columns'] as List? ?? []).map((e)=>'$e').toList();
    final rows=(_report?['rows'] as List? ?? []).where((row)=>(row as List).join(' ').toLowerCase().contains(_query.toLowerCase())).toList();
    return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(widget.title,style:Theme.of(context).textTheme.titleLarge),
      CafeText('${_date(_from)} to ${_date(_to)} · Baghdad time'),
      Wrap(spacing:8,children:[TextButton.icon(onPressed:_loading?null:_range,icon:const Icon(Icons.date_range),label:const CafeText('Dates')),TextButton.icon(onPressed:_loading?null:_load,icon:const Icon(Icons.refresh),label:const CafeText('Refresh')),TextButton.icon(onPressed:_loading||_error!=null||_report==null?null:_print,icon:const Icon(Icons.print_outlined),label:const CafeText('Print / save PDF'))]),
      if(_loading)const LinearProgressIndicator(),
      if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
      if(_report!=null && _error==null)...[
        CafeText('${_report!['note']}'),
        TextField(decoration:const InputDecoration(label: CafeText('Search report')),onChanged:(v)=>setState(()=>_query=v)),
        CafeText('${rows.length} matching records'),
        if(rows.isEmpty)const Padding(padding:EdgeInsets.all(24),child:CafeText('No recorded activity for this report.')),
        if(rows.isNotEmpty)SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:[for(final c in columns)DataColumn(label:Text(c))],rows:[for(final row in rows)DataRow(cells:[for(final value in row as List)DataCell(SelectableText(value==null?'—':'$value'))])])),
      ],
    ])));
  }
}
