import 'dart:async' show StreamController, StreamSubscription;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum UnityViewControllerStatus {
  created,
  reattached,
}

class UnityViewController {
  static UnityViewController get instance => _instance;
  static late final UnityViewController _instance;
  final int id;
  final MethodChannel _channel;
  final _messageStream = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageStream.stream;
  final _statusStream = StreamController<UnityViewControllerStatus>.broadcast();
  Stream<UnityViewControllerStatus> get statusStream => _statusStream.stream;

  UnityViewController(this.id) : _channel = MethodChannel('unity_view_$id') {
    _channel.setMethodCallHandler(_onEvent);
    if (id == 0) _instance = this;
  }

  Future<void> _onEvent(MethodCall call) async {
    switch (call.method) {
      case 'onUnityViewReattached':
        _statusStream.add(UnityViewControllerStatus.reattached);
        return;
      case 'onUnityViewMessage':
        _messageStream.add(call.arguments);
        return;
      default:
        throw UnimplementedError('Unimplemented method: ${call.method}');
    }
  }

  void dispose() {
    if (id == 0) return;
    _messageStream.close();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _channel.invokeMethod('dispose');
    }
    _channel.setMethodCallHandler(null);
  }

  void pause() {
    _channel.invokeMethod('pause');
  }

  void resume() {
    _channel.invokeMethod('resume');
  }

  void send(
    String gameObjectName,
    String methodName,
    String message,
  ) {
    _channel.invokeMethod('send', {
      'gameObjectName': gameObjectName,
      'methodName': methodName,
      'message': message,
    });
  }
}

typedef UnityViewCreatedCallback = void Function(UnityViewController controller);
typedef UnityViewReattachedCallback = void Function(UnityViewController controller);
typedef UnityViewMessageCallback = void Function(UnityViewController controller, String message);

class UnityView extends StatefulWidget {
  const UnityView({
    Key? key,
    this.onCreated,
    this.onReattached,
    this.onMessage,
  }) : super(key: key);

  final UnityViewCreatedCallback? onCreated;
  final UnityViewReattachedCallback? onReattached;
  final UnityViewMessageCallback? onMessage;

  @override
  _UnityViewState createState() => _UnityViewState();
}

class _UnityViewState extends State<UnityView> {
  UnityViewController? controller;
  late StreamSubscription messageSub;
  late StreamSubscription statusSub;

  @override
  void dispose() {
    messageSub.cancel();
    statusSub.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: 'unity_view',
          onPlatformViewCreated: onPlatformViewCreated,
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: 'unity_view',
          onPlatformViewCreated: onPlatformViewCreated,
        );
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  void onPlatformViewCreated(int id) {
    final newController = UnityViewController(id);

    controller = newController;

    messageSub = newController.messageStream.listen((message) {
      widget.onMessage?.call(newController, message);
    });

    statusSub = newController.statusStream.listen((status) {
      widget.onReattached?.call(newController);
    });

    widget.onCreated?.call(newController);
  }
}
