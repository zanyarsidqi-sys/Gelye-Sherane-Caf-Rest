import 'dart:async';
import 'app_language.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only scheduling; guest QR orders require verified active stays in a future upgrade.
class MotelScheduledMealsScreen extends StatefulWidget {
  const MotelScheduledMealsScreen({super.key});
  @override
  State<MotelScheduledMealsScreen> createState() => _MotelScheduledMealsScreenState();
}
class _MotelScheduledMealsScreenState extends State<MotelScheduledMealsScreen> with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _loadingMeals = false;
  bool _foreground = true;
  final room = TextEditingController();
  final description = TextEditingController();
  DateTime? delivery;
  bool saving = false;
  String? error;
  List<Map<String,dynamic>> meals = [];
  String queueFilter = 'all';
  bool isOverdue(Map<String,dynamic> meal) {
    final status = meal['status']?.toString();
    if (status == 'delivered' || status == 'rejected' || status == 'cancelled') return false;
    final due = DateTime.tryParse(meal['requested_for']?.toString() ?? '');
    return due != null && due.isBefore(DateTime.now());
  }
  bool matchesFilter(Map<String,dynamic> meal) {
    switch (queueFilter) {
      case 'requested': return meal['status'] == 'requested';
      case 'overdue': return isOverdue(meal);
      case 'active': return const {'confirmed','scheduled','preparing','ready','on_way'}.contains(meal['status']);
      default: return true;
    }
  }

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); load(); _refreshTimer = Timer.periodic(const Duration(seconds:15), (_) { if (_foreground && !saving && deciding.isEmpty) load(); }); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) load();
  }
  @override void dispose() { _refreshTimer?.cancel(); WidgetsBinding.instance.removeObserver(this); room.dispose(); description.dispose(); super.dispose(); }
  Future<void> load() async {
    if (_loadingMeals || !mounted) return;
    _loadingMeals = true;
    try {
      final data = await Supabase.instance.client.rpc('gs_staff_list_motel_scheduled_meals');
      if (mounted) setState(() { meals = (data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList(); error=null; });
    } catch (_) { if (mounted) setState(() => error='Unable to load scheduled meals. Check permissions and migrations.'); }
    finally { _loadingMeals = false; }
  }
  Future<void> pickTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context, firstDate: DateTime(now.year,now.month,now.day), lastDate: now.add(const Duration(days:90)), initialDate: now.add(const Duration(days:1)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context:context, initialTime:const TimeOfDay(hour:19,minute:0));
    if (time == null || !mounted) return;
    setState(() => delivery=DateTime(day.year,day.month,day.day,time.hour,time.minute));
  }
  Future<void> submit() async {
    if (saving) return;
    if (room.text.trim().isEmpty || description.text.trim().length<3 || delivery==null || !delivery!.isAfter(DateTime.now().add(const Duration(minutes:15)))) {
      setState(() => error='Enter a registered room, meal details, and a future delivery time.'); return;
    }
    setState(() { saving=true; error=null; });
    try {
      await Supabase.instance.client.rpc('gs_staff_schedule_motel_meal',params:{'p_room_label':room.text.trim(),'p_description':description.text.trim(),'p_requested_for':delivery!.toUtc().toIso8601String()});
      if (!mounted) return;
      description.clear(); setState(() => delivery=null);
      await load();
    } catch (_) { if (mounted) setState(() => error='Could not schedule. Confirm the room, time and edit permission.'); }
    finally { if (mounted) setState(() => saving=false); }
  }
  final Set<String> deciding = {};
  Future<void> decide(Map<String,dynamic> meal, String decision) async {
    final id = meal['id']?.toString();
    if (id == null || deciding.contains(id)) return;
    String? reason;
    if (decision == 'reject') {
      final controller = TextEditingController();
      try {
        reason = await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
          title:const Text('Reject meal request'),
          content:TextField(controller:controller,maxLength:500,maxLines:2,
            decoration:const InputDecoration(labelText:'Reason (required)')),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Reject'))],
        ));
      } finally { controller.dispose(); }
      if (reason == null) return;
      if (reason.length < 3) { if(mounted) setState(()=>error='Enter a rejection reason of at least 3 characters.'); return; }
    }
    setState(() { deciding.add(id); error=null; });
    try {
      await Supabase.instance.client.rpc('gs_staff_decide_motel_scheduled_meal',params:{
        'p_meal_id':id,'p_decision':decision,'p_reason':reason,
      });
      await load();
    } catch (_) {
      if(mounted) setState(()=>error='Could not update meal. Check edit permission and request status.');
    } finally { if(mounted) setState(()=>deciding.remove(id)); }
  }
  Future<void> advance(Map<String,dynamic> meal, String next) async {
    final id = meal['id']?.toString();
    if (id == null || deciding.contains(id)) return;
    setState(() { deciding.add(id); error=null; });
    try {
      await Supabase.instance.client.rpc('gs_staff_progress_motel_scheduled_meal',params:{
        'p_meal_id':id, 'p_next_status':next,
      });
      await load();
    } catch (_) {
      if(mounted) setState(()=>error='Unable to advance this meal. Check permission, current status and database migration.');
    } finally { if(mounted) setState(()=>deciding.remove(id)); }
  }
  String? nextStatus(String? current) {
    const transitions={'confirmed':'scheduled','scheduled':'preparing',
      'preparing':'ready','ready':'on_way','on_way':'delivered'};
    return transitions[current];
  }
  String t(String english) => AppLanguage.label(AppLanguage.of(context), english);
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('Scheduled Special Meals'),style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const Text('Employee screen · Requests refresh every 15 seconds while open. Status updates are staff-managed; no automatic kitchen ticket or room charge is created.'),
    TextField(controller:room,maxLength:100,decoration:InputDecoration(labelText:t('Registered room / villa number'))),
    TextField(controller:description,maxLength:500,maxLines:3,decoration:InputDecoration(labelText:t('Meal, dishes and special instructions'))),
    OutlinedButton.icon(onPressed:pickTime,icon:const Icon(Icons.event),label:Text(delivery==null?t('Choose delivery date and time'):'Delivery: ${delivery!.toLocal()}')),
    FilledButton(onPressed:saving?null:submit,child:Text(saving?t('Saving…'):t('Create scheduled request'))),
    if(error!=null) Text(error!,style:const TextStyle(color:Colors.red)),
    const Divider(),
    Row(children:[Expanded(child:Text(t('Scheduled requests'),style:TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
    Wrap(spacing:8,runSpacing:4,children:[
      for(final option in const {'all':'All','requested':'Needs approval','active':'In progress','overdue':'Overdue'}.entries)
        ChoiceChip(label:Text(option.value),selected:queueFilter==option.key,
          onSelected:(_)=>setState(()=>queueFilter=option.key)),
    ]),
    Text('Pending approval: ${meals.where((m)=>m['status']=='requested').length}  ·  Overdue: ${meals.where(isOverdue).length}',
      style:const TextStyle(fontWeight:FontWeight.w600)),
    if (meals.where(matchesFilter).isEmpty) const Padding(
      padding:EdgeInsets.symmetric(vertical:20),child:Text('No scheduled meals match this filter.')),
    for(final m in meals.where(matchesFilter)) Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        ListTile(title:Text('${m['room_label']} — ${m['room_name']}'),
          subtitle:Text('${m['meal_description']}\n${m['requested_for']} · ${m['status']}${isOverdue(m) ? ' · OVERDUE' : ''}')),
        if(nextStatus(m['status']?.toString()) != null)
          FilledButton.tonal(
            onPressed:deciding.contains(m['id'].toString())?null:()=>advance(m,nextStatus(m['status']?.toString())!),
            child:Text('Mark ${nextStatus(m['status']?.toString())!.replaceAll('_',' ')}'),
          ),
        if(m['status']=='requested') Wrap(spacing:8,children:[
          FilledButton(onPressed:deciding.contains(m['id'].toString())?null:()=>decide(m,'confirm'),child:const Text('Confirm')),
          OutlinedButton(onPressed:deciding.contains(m['id'].toString())?null:()=>decide(m,'reject'),child:const Text('Reject')),
        ]),
      ],
    ))),
  ]);
}
