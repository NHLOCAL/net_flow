import 'package:flutter/services.dart';

class AndroidBrowserChannel {
  AndroidBrowserChannel({
    MethodChannel channel = const MethodChannel('net_flow/browser'),
  }) : _channel = channel;

  final MethodChannel _channel;

  void setOpenUrlHandler(Future<void> Function(String url) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openUrl' && call.arguments is String) {
        await handler(call.arguments as String);
      }
    });
  }

  Future<String?> getInitialUrl() {
    return _channel.invokeMethod<String>('getInitialUrl');
  }

  Future<bool> isDefaultBrowserRoleAvailable() async {
    return await _channel.invokeMethod<bool>(
          'isDefaultBrowserRoleAvailable',
        ) ??
        false;
  }

  Future<bool> isDefaultBrowserRoleHeld() async {
    return await _channel.invokeMethod<bool>('isDefaultBrowserRoleHeld') ??
        false;
  }

  Future<void> requestDefaultBrowserRole() {
    return _channel.invokeMethod<void>('requestDefaultBrowserRole');
  }
}
