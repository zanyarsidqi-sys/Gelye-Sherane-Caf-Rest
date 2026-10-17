import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';
import 'evidence_browser_stub.dart'
    if (dart.library.js_interop) 'evidence_browser_web.dart' as browser;

class CafeMenuAssets extends StatefulWidget {
  const CafeMenuAssets({super.key, required this.images, this.client});
  final bool images;
  final SupabaseClient? client;
  @override
  State<CafeMenuAssets> createState() => _CafeMenuAssetsState();
}
class _CafeMenuAssetsState extends State<CafeMenuAssets> {
  List<Map<String,dynamic>> _rows = [];
  bool _loading=true, _busy=false;
  String? _error;
  String _query='';
  @override
  void initState() {super.initState(); _load();}
  Future<dynamic> _call(String action, {String? id, String? text}) async {
    final client=widget.client;
    if(client==null) throw StateError('Connection unavailable');
    return client.rpc('manage_cafe_menu_assets', params:{'p_action':action,'p_id':id,'p_text':text});
  }
  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final rows=cafeRows(await _call(widget.images?'images':'categories'));
      if(mounted)setState((){_rows=rows;_error=null;});
    } catch (_) {if(mounted)setState(()=>_error='Unable to load. Check your connection and menu permissions.');}
    finally {if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _category([Map<String,dynamic>? row]) async {
    final controller=TextEditingController(text:row?['name'] as String?);
    final form=GlobalKey<FormState>();
    final name=await showDialog<String>(context:context,builder:(context)=>AlertDialog(
      title:Text(row==null?'Add category':'Rename category'),
      content:Form(key:form,child:TextFormField(controller:controller,maxLength:60,decoration:const InputDecoration(labelText:'Category name'),validator:(v)=>(v?.trim().isEmpty??true)?'Enter a category name':null)),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(context,controller.text.trim());},child:const Text('Save'))]));
    controller.dispose();
    if(name==null||!mounted)return;
    setState(()=>_busy=true);
    try {await _call('save_category',id:row?['id'] as String?,text:name); if(mounted)await _load();}
    catch (_){if(mounted)setState(()=>_error='Category not confirmed. Refresh before retrying; category names must be unique.');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _upload(Map<String,dynamic> row) async {
    setState(()=>_busy=true);
    try {
      final file=await browser.pickEvidenceFile();
      if(file==null)return;
      final bytes=file.bytes;
      final png=bytes.length>8&&bytes[0]==137&&bytes[1]==80&&bytes[2]==78&&bytes[3]==71;
      final jpg=bytes.length>3&&bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
      if(bytes.length>5242880||(!png&&!jpg))throw const FormatException('Choose a JPEG or PNG up to 5 MB.');
      if(!mounted)return;
      final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text("Product picture · ${row['name']}"),content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[Image.memory(bytes,height:200,fit:BoxFit.contain,errorBuilder:(_,e,s)=>const Text('Invalid image')),const Text('This product image will be publicly accessible.')])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Upload'))]));
      if(yes!=true)return;
      final client=widget.client!;
      final path="${client.auth.currentUser!.id}/${row['id']}/${newCafeRequestId()}${png ? '.png' : '.jpg'}";
      await client.storage.from('cafe-product-images').uploadBinary(path,bytes,fileOptions:FileOptions(contentType:png?'image/png':'image/jpeg',upsert:false));
      await _call('set_image',id:row['id'] as String,text:path);
      if(mounted)await _load();
    } catch (_) {if(mounted)setState(()=>_error='Image upload not confirmed. Use a JPEG or PNG up to 5 MB, then refresh before retrying.');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _remove(Map<String,dynamic> row) async {
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Remove product picture?'),content:const Text('The product stays saved. The previous uploaded file remains in storage.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Remove'))]));
    if(yes!=true||!mounted)return;
    setState(()=>_busy=true);
    try {await _call('set_image',id:row['id'] as String);if(mounted)await _load();}
    catch (_){if(mounted)setState(()=>_error='Removal not confirmed. Refresh and check the product.');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context) {
    final enabled=!_busy&&!_loading&&_error==null;
    final rows=_rows.where((r)=>"${r['name']} ${r['category'] ?? ''}".toLowerCase().contains(_query.toLowerCase())).toList();
    return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(widget.images?'Product Pictures':'Product Categories',style:Theme.of(context).textTheme.titleLarge),
      Text(widget.images?'Choose a saved product to upload, replace or remove its picture.':'Add categories before creating products. Renaming updates the current product catalog.'),
      Wrap(spacing:8,children:[if(!widget.images)FilledButton.icon(onPressed:enabled?()=>_category():null,icon:const Icon(Icons.add),label:const Text('Add category')),TextButton.icon(onPressed:_loading||_busy?null:_load,icon:const Icon(Icons.refresh),label:const Text('Refresh'))]),
      if(_loading||_busy)const LinearProgressIndicator(),
      if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
      TextField(decoration:const InputDecoration(labelText:'Search'),onChanged:(v)=>setState(()=>_query=v)),
      if(!_loading&&rows.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('No matching records.')),
      for(final row in rows)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(widget.images&&row['image_path']!=null&&widget.client!=null)Image.network(widget.client!.storage.from('cafe-product-images').getPublicUrl(row['image_path'] as String),height:140,width:180,fit:BoxFit.cover,errorBuilder:(_,e,s)=>const Text('Picture unavailable')),
        Text(row['name'].toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
        Text(widget.images?(row['category']??'').toString():"${row['product_count']} products"),
        Wrap(spacing:8,children:[OutlinedButton(onPressed:enabled?()=>widget.images?_upload(row):_category(row):null,child:Text(widget.images?'Upload / replace picture':'Rename')),
          if(widget.images&&row['image_path']!=null)TextButton(onPressed:enabled?()=>_remove(row):null,child:const Text('Remove picture'))]),
      ]))),
    ])));
  }
}
