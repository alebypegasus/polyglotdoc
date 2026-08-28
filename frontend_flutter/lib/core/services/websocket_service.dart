import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _progressController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  String _clientId = 'flutter_client';
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get progressStream => _progressController.stream;
  bool get isConnected => _isConnected;

  void connect(String clientId) {
    _clientId = clientId;
    _isDisposed = false;
    _initConnection();
  }

  void _initConnection() {
    if (_isDisposed) return;

    try {
      final wsUrl = Uri.parse(AppConstants.wsProgressUrl(_clientId));
      dev.log('Connecting to WebSocket: $wsUrl', name: 'WebSocketService');

      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = json.decode(data.toString()) as Map<String, dynamic>;
            _progressController.add(parsed);
          } catch (e) {
            dev.log('Error parsing WS message: $e', name: 'WebSocketService');
          }
        },
        onError: (err) {
          dev.log('WebSocket stream error: $err', name: 'WebSocketService');
          _scheduleReconnect();
        },
        onDone: () {
          dev.log('WebSocket stream closed', name: 'WebSocketService');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _startPingHeartbeat();
    } catch (e) {
      dev.log('Failed to connect to WS: $e', name: 'WebSocketService');
      _scheduleReconnect();
    }
  }

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (e) {
          dev.log('Failed to send ping: $e', name: 'WebSocketService');
        }
      }
    });
  }

  void _scheduleReconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    if (!_isDisposed) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        dev.log('Attempting WebSocket reconnection...', name: 'WebSocketService');
        _initConnection();
      });
    }
  }

  void dispose() {
    _isDisposed = true;
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _progressController.close();
  }
}
