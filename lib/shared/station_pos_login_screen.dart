import 'package:flutter/material.dart';
import '../services/station_device_session_service.dart';

/// Station-device login. Stores only the session token in platform secure storage.
class StationPosLoginScreen extends StatefulWidget {
 const StationPosLoginScreen({super.key, required this.onAuthenticated});
 final void Function(String stationKey, bool orderPrint, bool billPrint) onAuthenticated;
 @override State<StationPosLoginScreen> createState() => _StationPosLoginScreenState();
}
class _StationPosLoginScreenState extends State<StationPosLoginScreen> {
 final _username = TextEditingController();
 final _password = TextEditingController();
 bool _busy = false, _obscure = true;
 String? _error;
 @override void dispose() { _username.dispose(); _password.dispose(); super.dispose(); }
 Future<void> _login() async {
  if (_busy || _username.text.trim().isEmpty || _password.text.isEmpty) return;
  setState(() { _busy = true; _error = null; });
  try {
   final data = await StationDeviceSessionService().signIn(_username.text.trim(), _password.text);
   final station = data['station']?.toString();
   if (station == null || station.isEmpty || data['token'] is! String) throw StateError('Invalid response');
   if (!mounted) return;
   _password.clear();
   widget.onAuthenticated(station, data['order_print'] == true, data['bill_print'] == true);
   } on StationEmployeeAuthorizationException {
    if (mounted) {
     setState(() => _error =
       'Verified employee access is required before station sign-in.');
    }
   } catch (_) {
   if (mounted) setState(() => _error = 'Unable to sign in. Check credentials or try later.');
  } finally { if (mounted) setState(() => _busy = false); }
 }
 @override Widget build(BuildContext context) => Scaffold(
  appBar: AppBar(title: const Text('Station POS sign in')),
  body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
   child: ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
    const Text('Sign in to this station device',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    const SizedBox(height:16),
    TextField(controller:_username,autocorrect:false,decoration:const InputDecoration(labelText:'Station username')),
    const SizedBox(height:12),
    TextField(controller:_password,obscureText:_obscure,autocorrect:false,enableSuggestions:false,
     decoration:InputDecoration(labelText:'Station password',suffixIcon:IconButton(
      onPressed:()=>setState(()=>_obscure=!_obscure),icon:Icon(_obscure?Icons.visibility:Icons.visibility_off)))),
    if (_error != null) Padding(padding:const EdgeInsets.only(top:12),child:Text(_error!,style:const TextStyle(color:Colors.red))),
    const SizedBox(height:16),
    FilledButton(onPressed:_busy?null:_login,child:Text(_busy?'Signing in…':'Sign in')),
    const SizedBox(height:12),
     const Text(
      'Station access ends when this employee session ends, the device is revoked, or the session expires.',
     ),
   ]))),
 );
}
