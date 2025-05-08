import 'package:flutter/material.dart';
import '../models/rdp_connection.dart';
import '../services/native_rdp_service.dart';

class EmbeddedRdpScreen extends StatefulWidget {
  final RdpConnection connection;

  const EmbeddedRdpScreen({Key? key, required this.connection})
      : super(key: key);

  @override
  State<EmbeddedRdpScreen> createState() => _EmbeddedRdpScreenState();
}

class _EmbeddedRdpScreenState extends State<EmbeddedRdpScreen> {
  final NativeRdpService _rdpService = NativeRdpService();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connectToRdp();
  }

  @override
  void dispose() {
    _disconnectRdp();
    super.dispose();
  }

  Future<void> _connectToRdp() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      await _rdpService.connectRdp(widget.connection);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnectRdp() async {
    try {
      await _rdpService.disconnectRdp();
    } catch (e) {
      // Çıkış sırasında hata olursa sadece logla
      debugPrint('RDP bağlantısı kapatılırken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Bağlantıyı Yenile',
            onPressed: _connectToRdp,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'RDP bağlantısı başlatılamadı',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _connectToRdp,
              child: const Text('Yeniden Dene'),
            ),
          ],
        ),
      );
    }

    if (_isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('RDP bağlantısı başlatılıyor...'),
          ],
        ),
      );
    }

    return _rdpService.buildRdpView(widget.connection);
  }
}
