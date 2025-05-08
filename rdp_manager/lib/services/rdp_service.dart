import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rdp_connection.dart';

class RdpService {
  static final RdpService _instance = RdpService._internal();
  factory RdpService() => _instance;
  RdpService._internal();

  Future<bool> launchRdpConnection(RdpConnection connection) async {
    if (Platform.isWindows) {
      // Windows - RDP dosyası oluştur ve çalıştır
      try {
        // Geçici dosya için klasör al
        final tempDir = await getTemporaryDirectory();
        final random = Random().nextInt(10000);
        final rdpFilePath = '${tempDir.path}\\connection_${random}.rdp';

        // RDP dosyası içeriğini oluştur
        final rdpContent = '''
full address:s:${connection.hostname}:${connection.port}
username:s:${connection.username}
password:s:${connection.password}
screen mode id:i:1
prompt for credentials:i:0
administrative session:i:0
authentication level:i:0
''';

        // Dosyayı oluştur ve içeriği yaz
        final file = File(rdpFilePath);
        await file.writeAsString(rdpContent);

        // Dosyayı çalıştır
        final result = await Process.run('mstsc.exe', [rdpFilePath]);

        // Hata durumunu kontrol et
        if (result.exitCode != 0) {
          print('RDP bağlantı hatası. Çıkış kodu: ${result.exitCode}');
          print('Hata: ${result.stderr}');
          print('Çıktı: ${result.stdout}');
          return false;
        }

        // Birkaç saniye bekleyip geçici dosyayı sil
        await Future.delayed(const Duration(seconds: 5));
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Dosya silme hatası önemli değil
          print('Geçici RDP dosyası silinemedi: $e');
        }

        return true;
      } catch (e) {
        print('RDP bağlantı başlatma hatası: $e');
        return false;
      }
    } else if (Platform.isMacOS) {
      // macOS - Requires Microsoft Remote Desktop application
      String url =
          'rdp://${connection.username}:${connection.password}@${connection.hostname}:${connection.port}';
      final Uri uri = Uri.parse(url);

      try {
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        } else {
          print('Error: Microsoft Remote Desktop app might not be installed');
          return false;
        }
      } catch (e) {
        print('Error launching RDP connection: $e');
        return false;
      }
    } else if (Platform.isLinux) {
      // Linux - using xfreerdp
      try {
        await Process.run('xfreerdp', [
          '/v:${connection.hostname}:${connection.port}',
          '/u:${connection.username}',
          '/p:${connection.password}',
          '/cert-ignore'
        ]);
        return true;
      } catch (e) {
        print('Error launching RDP connection: $e');
        return false;
      }
    }

    return false;
  }
}
