import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'config.dart';

class RealtimeEvent {
  final String name;
  final dynamic data;
  RealtimeEvent(this.name, this.data);
}

/// Wraps the Socket.IO connection to the NestJS gateway.
/// The app shell connects after login; feature pages listen to [events].
class RealtimeService {
  socket_io.Socket? _socket;
  final StreamController<RealtimeEvent> _events = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String accessToken) {
    disconnect();
    _socket = socket_io.io(
      apiBaseUrl,
      socket_io.OptionBuilder()
          .setTransports(['polling', 'websocket'])
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .enableReconnection()
          .build(),
    );
    _socket!.onConnect((_) => debug('connected'));
    _socket!.onDisconnect((_) => debug('disconnected'));
    _socket!.onConnectError((e) => debug('connect error: $e'));
    _socket!.onAny((event, data) {
      if (!_events.isClosed) _events.add(RealtimeEvent(event, data));
    });
    _socket!.connect();
  }

  void emit(String event, dynamic data) => _socket?.emit(event, data);

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void debug(String msg) {
    // Intentionally quiet in production; override to enable logging.
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}

final realtimeProvider = Provider<RealtimeService>((ref) {
  final svc = RealtimeService();
  ref.onDispose(svc.dispose);
  return svc;
});
