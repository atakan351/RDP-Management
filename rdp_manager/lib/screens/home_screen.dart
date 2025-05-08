import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/rdp_connection.dart';
import '../models/app_settings.dart';
import '../services/database_service.dart';
import '../services/rdp_service.dart';
import '../services/ping_service.dart';
import 'rdp_form_screen.dart';
// import 'embedded_rdp_screen.dart'; // Şimdilik devre dışı

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final RdpService _rdpService = RdpService();
  final PingService _pingService = PingService();
  List<RdpConnection> _connections = [];
  bool _isLoading = false;
  Map<String, List<RdpConnection>> _categorizedConnections = {};
  Map<int?, bool> _connectionStatus = {}; // Bağlantı durumlarını saklayan map
  Set<int?> _checkingConnections = {}; // Şu anda kontrol edilen bağlantılar
  bool _isCheckingAllStatuses = false; // Tüm bağlantılar kontrol ediliyor mu

  // Arama işlevi için
  String _searchQuery = '';
  Map<String, List<RdpConnection>> _filteredConnections = {};
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Uygulama ayarları
  AppSettings _appSettings = AppSettings();

  // Bildirim sistemi için
  Map<int?, DateTime> _offlineSince =
      {}; // Sunucuların ne zamandan beri çevrimdışı olduğunu tutan map
  Map<int?, bool> _previousStatus = {}; // Önceki durum bilgisi
  int _offlineCount = 0; // Çevrimdışı sunucu sayısı

  // Otomatik ping kontrolü için
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = false;
  int _autoRefreshInterval = 5; // Saniye cinsinden kontrol aralığı
  int _lastRefreshTimestamp = 0; // Son kontrol zamanı

  @override
  void initState() {
    super.initState();
    // Veritabanı operasyonlarını uygun şekilde başlatmak için
    Future.delayed(Duration.zero, () {
      _loadSettings();
      _loadConnections();
    });
  }

  @override
  void dispose() {
    // Widget dispose edildiğinde Timer'ı iptal et
    _stopAutoRefresh();
    _searchController.dispose();
    super.dispose();
  }

  // Otomatik yenilemeyi başlat
  void _startAutoRefresh() {
    // Zaten çalışıyorsa durdur ve yeniden başlat
    _stopAutoRefresh();

    setState(() {
      _autoRefreshEnabled = true;
    });

    // Başlangıçta hemen bir kontrol yap
    _checkAllConnectionStatuses();

    // Belirtilen aralıkta düzenli olarak kontrol et
    _autoRefreshTimer = Timer.periodic(Duration(seconds: _autoRefreshInterval),
        (_) => _checkAllConnectionStatuses());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Otomatik durum kontrolü başlatıldı (${_autoRefreshInterval}s)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Otomatik yenilemeyi durdur
  void _stopAutoRefresh() {
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer!.cancel();
      _autoRefreshTimer = null;

      setState(() {
        _autoRefreshEnabled = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Otomatik durum kontrolü durduruldu'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Yenileme aralığını ayarla
  void _showIntervalDialog() {
    final TextEditingController controller =
        TextEditingController(text: _autoRefreshInterval.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yenileme Aralığı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Bağlantı kontrolünün kaç saniyede bir yapılacağını belirtin:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saniye',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final interval = int.tryParse(controller.text);
              if (interval != null && interval > 0) {
                Navigator.pop(context);
                setState(() {
                  _autoRefreshInterval = interval;
                });

                // Eğer otomatik yenileme açıksa, güncellenen aralıkla yeniden başlat
                if (_autoRefreshEnabled) {
                  _startAutoRefresh();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Lütfen geçerli bir sayı girin')),
                );
              }
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // Ayarlar iletişim kutusunu göster
  void _showSettingsDialog() {
    final TextEditingController controller =
        TextEditingController(text: _appSettings.serversPerRow.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayarlar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Her satırda kaç adet sunucu görüntüleneceğini belirtin:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Satır başına sunucu sayısı',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              if (count != null && count > 0) {
                Navigator.pop(context);
                final newSettings = _appSettings.copyWith(serversPerRow: count);
                _updateSettings(newSettings);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Lütfen geçerli bir sayı girin')),
                );
              }
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // Bildirim panelini göster
  void _showNotificationsPanel() {
    // Çevrimdışı olan bağlantıları bul
    final offlineConnections = _connections.where((conn) {
      return _connectionStatus[conn.id] == false;
    }).toList();

    // Çevrimdışı süreleri hesapla
    final offlineDurations = <int?, String>{};
    for (var conn in offlineConnections) {
      if (_offlineSince.containsKey(conn.id)) {
        final duration = DateTime.now().difference(_offlineSince[conn.id]!);
        offlineDurations[conn.id] = _formatDuration(duration);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Bağlantı Bildirimleri',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: offlineConnections.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green[300],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tüm sunucular çevrimiçi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Bağlantı sorunu yaşanan sunucu yok',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            itemCount: offlineConnections.length,
                            itemBuilder: (context, index) {
                              final connection = offlineConnections[index];
                              final offlineDuration =
                                  offlineDurations[connection.id] ??
                                      'Bilinmiyor';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.computer,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    connection.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${connection.hostname}:${connection.port}'),
                                      Text(
                                        'Çevrimdışı süresi: $offlineDuration',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Yeniden Kontrol Et',
                                    onPressed: () {
                                      _checkSingleConnectionStatus(connection);
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (offlineConnections.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            _checkAllConnectionStatuses();
                            Navigator.pop(context);
                          },
                          child:
                              const Text('Tüm Bağlantıları Yeniden Kontrol Et'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Süreyi formatla
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} gün ${duration.inHours.remainder(24)} saat';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} saat ${duration.inMinutes.remainder(60)} dakika';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} dakika ${duration.inSeconds.remainder(60)} saniye';
    } else {
      return '${duration.inSeconds} saniye';
    }
  }

  Future<void> _loadConnections() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final connections = await _databaseService.getConnections();

      // Bağlantıları kategorilere göre grupla
      final categorized = <String, List<RdpConnection>>{};
      for (final connection in connections) {
        if (categorized.containsKey(connection.category)) {
          categorized[connection.category]!.add(connection);
        } else {
          categorized[connection.category] = [connection];
        }
      }

      if (mounted) {
        setState(() {
          _connections = connections;
          _categorizedConnections = categorized;
          _isLoading = false;
        });

        // Mevcut arama sorgusuna göre bağlantıları filtrele
        _filterConnections();

        // Bağlantı durumlarını kontrol et (ancak kullanıcı arayüzünü bloke etme)
        _checkAllConnectionStatuses();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connections = [];
          _categorizedConnections = {};
          _filteredConnections = {};
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantılar yüklenirken hata: $e')),
        );
      }
    }
  }

  // Tüm bağlantıların durumlarını kontrol et
  Future<void> _checkAllConnectionStatuses() async {
    if (_isCheckingAllStatuses || _connections.isEmpty) return;

    // Çok sık kontrol yapmayı engelle (en az 1 saniye aralık olsun)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRefreshTimestamp < 1000 && !_autoRefreshEnabled) {
      return;
    }
    _lastRefreshTimestamp = now;

    setState(() {
      _isCheckingAllStatuses = true;
    });

    // Paralel çalışacak kontrol işlemleri
    final futures = <Future>[];

    for (final connection in _connections) {
      // Her bağlantı için socket bağlantı kontrolü başlat
      futures.add(_checkSingleConnectionStatus(connection));
    }

    // Tüm bağlantı işlemlerinin tamamlanmasını bekle
    await Future.wait(futures);

    // Çevrimdışı sunucu sayısını güncelle
    if (mounted) {
      setState(() {
        _isCheckingAllStatuses = false;
        _offlineCount =
            _connectionStatus.values.where((status) => status == false).length;
      });
    }
  }

  // Tek bir bağlantının durumunu kontrol et
  Future<void> _checkSingleConnectionStatus(RdpConnection connection) async {
    if (!mounted || _checkingConnections.contains(connection.id)) return;

    setState(() {
      _checkingConnections.add(connection.id);
    });

    try {
      // Önceki durumu kaydet
      final previousStatus = _connectionStatus[connection.id];
      _previousStatus[connection.id] = previousStatus ?? false;

      // Sunucuya belirtilen porta TCP bağlantı dene (ping yerine telnet benzeri)
      final isReachable = await _pingService.checkConnection(
        connection.hostname,
        connection.port,
      );

      if (mounted) {
        setState(() {
          _connectionStatus[connection.id] = isReachable;
          _checkingConnections.remove(connection.id);

          // Eğer durum çevrimdışı'ya değiştiyse zaman damgasını güncelle
          if (isReachable == false &&
              (previousStatus == null || previousStatus == true)) {
            _offlineSince[connection.id] = DateTime.now();

            // Sunucu bağlantısı kesildiğinde SnackBar göster
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 10),
                      Text('${connection.name} bağlantısı kesildi!'),
                    ],
                  ),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          // Eğer durum çevrimiçi'ye değiştiyse ve daha önce çevrimdışı ise zaman damgasını temizle
          if (isReachable == true && previousStatus == false) {
            _offlineSince.remove(connection.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Önceki durumu kaydet
          final previousStatus = _connectionStatus[connection.id];
          _previousStatus[connection.id] = previousStatus ?? false;

          _connectionStatus[connection.id] = false;
          _checkingConnections.remove(connection.id);

          // Eğer durum çevrimdışı'ya değiştiyse zaman damgasını güncelle
          if (previousStatus == null || previousStatus == true) {
            _offlineSince[connection.id] = DateTime.now();

            // Hata durumunda da SnackBar göster
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Text('${connection.name} bağlantısı kesildi!'),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _deleteConnection(RdpConnection connection) async {
    await _databaseService.deleteConnection(connection.id!);

    // Bağlantı silindiğinde ilgili kayıtları da temizle
    setState(() {
      _connectionStatus.remove(connection.id);
      _offlineSince.remove(connection.id);
      _previousStatus.remove(connection.id);
      _checkingConnections.remove(connection.id);
    });

    _loadConnections();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${connection.name} silindi')),
    );
  }

  Future<void> _launchRdpConnection(RdpConnection connection) async {
    final result = await _rdpService.launchRdpConnection(connection);

    if (!result) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RDP bağlantısı başlatılamadı')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryBackgroundColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RDP Yöneticisi'),
        actions: [
          // Bildirim ikonu
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Bildirimler',
                onPressed: _showNotificationsPanel,
              ),
              if (_offlineCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _offlineCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // Ayarlar ikonu
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ayarlar',
            onPressed: _showSettingsDialog,
          ),

          // Otomatik yenileme kontrolü
          IconButton(
            icon: Icon(
              _autoRefreshEnabled ? Icons.timer : Icons.timer_off,
              color: _autoRefreshEnabled ? Colors.green : null,
            ),
            tooltip: _autoRefreshEnabled
                ? 'Otomatik Kontrol Açık'
                : 'Otomatik Kontrol Kapalı',
            onPressed: () {
              if (_autoRefreshEnabled) {
                _stopAutoRefresh();
              } else {
                _startAutoRefresh();
              }
            },
          ),

          // Yenileme aralığı ayarı
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Yenileme Aralığını Ayarla',
            onPressed: _showIntervalDialog,
          ),

          // Manuel yenileme
          _isCheckingAllStatuses
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _loadConnections();
                  },
                  tooltip: 'Yenile',
                ),
        ],
      ),
      body: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Sunucu ara...',
                    border: InputBorder.none,
                    icon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isSearching = false;
                                _filterConnections();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                      _isSearching = query.isNotEmpty;
                      _filterConnections();
                    });
                  },
                ),
              ),
            ),
          ),

          // İçerik
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _connections.isEmpty
                    ? _buildEmptyState()
                    : _buildCategorizedConnectionsList(categoryBackgroundColor),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RdpFormScreen(),
            ),
          );
          _loadConnections();
        },
        child: const Icon(Icons.add),
        tooltip: 'Bağlantı Ekle',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.desktop_windows_outlined,
              size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Henüz hiç RDP bağlantınız yok',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Bağlantı Ekle'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RdpFormScreen(),
                ),
              );
              _loadConnections();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedConnectionsList(Color categoryBackgroundColor) {
    // Arama sonuçları için kullanılacak olan kategoriler
    final connectionMap =
        _searchQuery.isEmpty ? _categorizedConnections : _filteredConnections;
    final sortedCategories = connectionMap.keys.toList()..sort();

    if (sortedCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Arama sonucu bulunamadı',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$_searchQuery" ile eşleşen sunucu yok',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final connectionsInCategory = connectionMap[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 24),
            // Kategori başlığı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: categoryBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${connectionsInCategory.length})',
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Kategori içindeki bağlantılar - Grid düzeninde
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _appSettings.serversPerRow,
                  childAspectRatio: 3 / 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: connectionsInCategory.length,
                itemBuilder: (context, idx) {
                  return _buildConnectionCard(connectionsInCategory[idx]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionCard(RdpConnection connection) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Bağlantı durumunu belirle (varsayılan olarak bilinmiyor/gri)
    final bool? isOnline = _connectionStatus[connection.id];
    final Color statusColor = isOnline == null
        ? Colors.grey // Durum henüz kontrol edilmedi
        : isOnline
            ? Colors.green // Çevrimiçi
            : Colors.red; // Çevrimdışı

    // Kontrol ediliyor mu?
    final bool isChecking = _checkingConnections.contains(connection.id);

    // Çevrimdışı süre bilgisi
    String offlineTime = '';
    if (isOnline == false && _offlineSince.containsKey(connection.id)) {
      final duration = DateTime.now().difference(_offlineSince[connection.id]!);
      offlineTime = _formatDuration(duration);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _launchRdpConnection(connection),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sunucu adı ve durum göstergesi
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.blueGrey.shade700
                              : Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isChecking
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.computer,
                                size: 16,
                                color: statusColor,
                              ),
                      ),
                      if (!isChecking)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? Colors.black : Colors.white,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connection.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Sunucu bilgileri
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${connection.hostname}:${connection.port}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Kullanıcı: ${connection.username}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isOnline == false && offlineTime.isNotEmpty)
                      Text(
                        'Çevrimdışı: $offlineTime',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (connection.description.isNotEmpty &&
                        (isOnline != false || offlineTime.isEmpty) &&
                        connection.description.length <= 50)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          connection.description,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Butonlar
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.swap_calls),
                    tooltip: 'Bağlantı Kontrolü',
                    onPressed: isChecking
                        ? null
                        : () => _checkSingleConnectionStatus(connection),
                  ),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.edit),
                    tooltip: 'Düzenle',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RdpFormScreen(connection: connection),
                        ),
                      );
                      _loadConnections();
                    },
                  ),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.delete),
                    tooltip: 'Sil',
                    onPressed: () => _showDeleteConfirmation(connection),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(RdpConnection connection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bağlantıyı Sil'),
        content: Text(
            '${connection.name} bağlantısını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConnection(connection);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Ayarları yükle
  Future<void> _loadSettings() async {
    try {
      final settings = await _databaseService.getSettings();
      setState(() {
        _appSettings = settings;
      });
    } catch (e) {
      // Ayarlar yüklenemezse varsayılan değerleri kullan
      setState(() {
        _appSettings = AppSettings();
      });
    }
  }

  // Ayarları güncelle ve kaydet
  Future<void> _updateSettings(AppSettings settings) async {
    setState(() {
      _appSettings = settings;
    });

    try {
      await _databaseService.saveSettings(settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayarlar kaydedilirken hata: $e')),
        );
      }
    }
  }

  // Arama sonuçlarını filtrele
  void _filterConnections() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredConnections =
            Map<String, List<RdpConnection>>.from(_categorizedConnections);
      });
      return;
    }

    final lowercaseQuery = _searchQuery.toLowerCase();
    final filteredMap = <String, List<RdpConnection>>{};

    // Her kategoriyi döngüye al
    _categorizedConnections.forEach((category, connections) {
      // Kategorideki her bağlantıyı filtrele
      final filteredConnections = connections.where((connection) {
        return connection.name.toLowerCase().contains(lowercaseQuery) ||
            connection.hostname.toLowerCase().contains(lowercaseQuery) ||
            connection.username.toLowerCase().contains(lowercaseQuery) ||
            connection.description.toLowerCase().contains(lowercaseQuery) ||
            category.toLowerCase().contains(lowercaseQuery);
      }).toList();

      // Eğer filtrelenmiş bağlantılar varsa, kategoriye ekle
      if (filteredConnections.isNotEmpty) {
        filteredMap[category] = filteredConnections;
      }
    });

    setState(() {
      _filteredConnections = filteredMap;
    });
  }
}
