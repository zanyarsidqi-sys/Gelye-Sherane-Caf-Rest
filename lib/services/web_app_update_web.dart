import 'dart:js_interop';

@JS('cafeApplyWebUpdate')
external JSPromise<JSAny?> _applyWebUpdate();

Future<void> applyWebAppUpdate() async {
  await _applyWebUpdate().toDart;
}
