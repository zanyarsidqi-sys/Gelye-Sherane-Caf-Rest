import 'dart:js_interop';
@JS('cafePushStatus')
external JSString _status();
@JS('cafePushEnable')
external JSPromise<JSString> _enable(JSString config);
@JS('cafePushTest')
external JSPromise<JSString> _test(JSString config);
@JS('cafePushDisable')
external JSPromise<JSString> _disable(JSString config);
String browserPushStatus() => _status().toDart;
Future<String> enableBrowserPush(String config) async => (await _enable(config.toJS).toDart).toDart;
Future<String> testBrowserPush(String config) async => (await _test(config.toJS).toDart).toDart;
Future<String> disableBrowserPush([String config = '']) async => (await _disable(config.toJS).toDart).toDart;
