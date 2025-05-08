import 'dart:io';
import 'package:flutter/foundation.dart';

class PingService {
  static final PingService _instance = PingService._internal();
  factory PingService() => _instance;
  PingService._internal();

  /// Belirtilen host ve porta bağlantı kurulabilir olup olmadığını kontrol eder
  Future<bool> checkConnection(String host, int port,
      {int timeoutSeconds = 2}) async {
    try {
      // Bağlantı kontrolü işlemini ayrı bir isolate'de çalıştır
      return await compute(_checkConnectionImpl,
          {'host': host, 'port': port, 'timeout': timeoutSeconds});
    } catch (e) {
      debugPrint('Bağlantı kontrolü hatası: $e');
      return false;
    }
  }
}

/// TCP bağlantı kontrolünü ayrı bir isolate'de gerçekleştir
Future<bool> _checkConnectionImpl(Map<String, dynamic> args) async {
  final host = args['host'];
  final port = args['port'];
  final timeoutSeconds = args['timeout'];

  try {
    // TCP soketi ile bağlantı denemesi yap (telnet benzeri)
    final socket = await Socket.connect(host, port,
        timeout: Duration(seconds: timeoutSeconds));

    // Bağlantı başarılı
    await socket.close();
    return true;
  } catch (e) {
    // Bağlantı hatası - sunucu ulaşılamaz veya port kapalı
    return false;
  }
}
