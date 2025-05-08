import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage();

  Future<void> savePassword(int connectionId, String password) async {
    await _storage.write(key: 'rdp_password_$connectionId', value: password);
  }

  Future<String?> getPassword(int connectionId) async {
    return await _storage.read(key: 'rdp_password_$connectionId');
  }

  Future<void> deletePassword(int connectionId) async {
    await _storage.delete(key: 'rdp_password_$connectionId');
  }

  Future<void> deleteAllPasswords() async {
    await _storage.deleteAll();
  }
}
