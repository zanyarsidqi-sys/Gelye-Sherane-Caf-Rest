String browserPushStatus() => 'unsupported';
Future<String> enableBrowserPush(String config) async => 'Open the website to enable browser notifications.';
Future<String> testBrowserPush(String config) async => 'Browser notifications are unavailable here.';
Future<String> disableBrowserPush([String config = '']) async => 'Browser notifications are unavailable here.';
