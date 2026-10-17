import 'package:flutter/material.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';

class CafeDashboardFulfilment extends StatefulWidget {
  const CafeDashboardFulfilment({super.key, required this.online, required this.walkIn, this.rpc});
  final bool online, walkIn;
  final CafeRpc? rpc;
  @override
  State<CafeDashboardFulfilment> createState()=>_CafeDashboardFulfilmentState();
}
class _CafeDashboardFulfilmentState extends State<CafeDashboardFulfilment> {
  late String _source = widget.online ? 'online' : 'walk_in';
  @override
  Widget build(BuildContext context) {
    if (!widget.online && !widget.walkIn) {
      return const CafeText('Online Orders or Active Walk-In Orders access has not been assigned.');
    }
    return CafeFinanceSurface(builder:(context)=>Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const CafeText('Takeaway & Delivery',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const CafeText('Track online and walk-in orders separately. Pickup versus delivery and driver assignment are not recorded in this workflow yet.'),
        Wrap(spacing:8,children:[
          if(widget.online) ChoiceChip(label:const CafeText('Online orders'),selected:_source=='online',
            onSelected:(_)=>setState(()=>_source='online')),
          if(widget.walkIn) ChoiceChip(label:const CafeText('Walk-in orders'),selected:_source=='walk_in',
            onSelected:(_)=>setState(()=>_source='walk_in')),
        ]),
        CafeOperationsWorkspace(key:ValueKey('fulfilment-$_source'),source:_source,
          title:_source=='online'?'Online orders':'Walk-in orders',canCreate:false,rpc:widget.rpc),
      ]));
  }
}
