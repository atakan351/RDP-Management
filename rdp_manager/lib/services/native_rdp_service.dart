import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rdp_connection.dart';

/// Windows platformu için native RDP uygulamasını entegre eden servis
class NativeRdpService {
  static final NativeRdpService _instance = NativeRdpService._internal();
  factory NativeRdpService() => _instance;
  NativeRdpService._internal();

  // Platform kanalı tanımla
  static const MethodChannel _channel =
      MethodChannel('com.example.rdp_manager/rdp_view');

  int? _viewId;
  final _viewKey = GlobalKey();

  /// RDP görünümü oluştur
  Widget buildRdpView(RdpConnection connection) {
    if (!Platform.isWindows) {
      return const Center(
        child: Text(
            'Gömülü RDP bağlantısı sadece Windows platformunda desteklenmektedir.'),
      );
    }

    return FutureBuilder<Widget>(
      future: _createRdpViewWidget(connection),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('RDP görünümü oluşturulamadı: ${snapshot.error}'),
          );
        } else if (snapshot.hasData) {
          return snapshot.data!;
        } else {
          return const Center(child: Text('RDP görünümü oluşturulamadı'));
        }
      },
    );
  }

  /// RDP görünümü widget'ı oluştur
  Future<Widget> _createRdpViewWidget(RdpConnection connection) async {
    try {
      // Plugin kurulumu ve ViewId alınması
      _viewId = await _channel.invokeMethod<int>('createRdpView', {
        'hostname': connection.hostname,
        'port': connection.port,
        'username': connection.username,
        'password': connection.password,
      });

      if (_viewId == null) {
        throw Exception('RDP görünümü oluşturulamadı');
      }

      // Windows'ta RDP görünümü temsil eden bir konteyner dön
      return Container(
        key: _viewKey,
        color: Colors.black,
        child: const Center(
          child: Text(
            'RDP Bağlantısı Açılıyor...',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } on PlatformException catch (e) {
      throw Exception('RDP görünümü oluşturulurken hata: ${e.message}');
    }
  }

  /// RDP oturumunu bağla/yeniden bağla
  Future<void> connectRdp(RdpConnection connection) async {
    if (_viewId == null) {
      throw Exception('RDP görünümü henüz oluşturulmadı');
    }

    try {
      await _channel.invokeMethod('connectRdp', {
        'viewId': _viewId,
        'hostname': connection.hostname,
        'port': connection.port,
        'username': connection.username,
        'password': connection.password,
      });
    } on PlatformException catch (e) {
      throw Exception('RDP bağlantısı yapılırken hata: ${e.message}');
    }
  }

  /// RDP oturumunu kapat
  Future<void> disconnectRdp() async {
    if (_viewId == null) {
      return;
    }

    try {
      await _channel.invokeMethod('disconnectRdp', {
        'viewId': _viewId,
      });
    } on PlatformException catch (e) {
      throw Exception('RDP bağlantısı kapatılırken hata: ${e.message}');
    }
  }

  /// RDP görünümünü yeniden boyutlandır
  Future<void> resizeRdpView() async {
    if (_viewId == null || _viewKey.currentContext == null) {
      return;
    }

    final RenderBox box =
        _viewKey.currentContext!.findRenderObject() as RenderBox;
    final size = box.size;

    try {
      await _channel.invokeMethod('resizeRdpView', {
        'viewId': _viewId,
        'width': size.width.toInt(),
        'height': size.height.toInt(),
      });
    } on PlatformException catch (e) {
      throw Exception(
          'RDP görünümü yeniden boyutlandırılırken hata: ${e.message}');
    }
  }
}
