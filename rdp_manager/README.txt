RDP YÖNETİCİSİ - TEKNİK DÖKÜMAN
=============================================

UYGULAMA GENEL BAKIŞ
-------------------
RDP Yöneticisi, Windows, Linux ve macOS ortamlarında çalışan, uzak masaüstü bağlantılarını (RDP) yönetmek için geliştirilmiş bir Flutter uygulamasıdır. Uygulama, çoklu RDP bağlantılarını kategorilere ayırarak saklama, düzenleme, silme ve bu bağlantıları başlatma yeteneklerine sahiptir. Ayrıca, sunucuların erişilebilirlik durumlarını otomatik olarak kontrol edebilir.

KULLANILAN TEKNOLOJİLER
-----------------------
- Dil: Dart 3.x
- Framework: Flutter (cross-platform UI toolkit)
- Veritabanı: SQLite (sqflite ile)
- Platform Desteği: Windows, Linux, macOS

MİMARİ YAPI
-----------
Uygulama, Model-View-Controller (MVC) benzeri bir mimari ile geliştirilmiştir:

1. Models (Modeller):
   - RdpConnection: Bağlantı bilgilerini tutan model sınıfı
   - AppSettings: Uygulama ayarlarını tutan model sınıfı

2. Services (Servisler):
   - DatabaseService: SQLite veritabanı işlemlerini yöneten servis
   - RdpService: RDP bağlantılarını başlatan servis
   - PingService: Sunucu bağlantı kontrollerini yapan servis

3. Screens (Ekranlar):
   - HomeScreen: Ana ekran, kategorilere ayrılmış RDP bağlantılarını listeler
   - RdpFormScreen: Bağlantı ekleme/düzenleme ekranı
   - EmbeddedRdpScreen: Gömülü RDP bağlantı ekranı (devre dışı)

ÖZELLİKLER
----------
1. RDP Bağlantılarını Yönetme:
   - Bağlantı ekleme, düzenleme ve silme
   - Bağlantıları kategorilere göre sınıflandırma
   - Tek tıkla RDP bağlantılarını başlatma

2. Sunucu Durumu İzleme:
   - Manuel veya otomatik sunucu durumu kontrolü
   - Zaman aşımına göre çevrimdışı sunucuları izleme
   - Çevrimdışı süre takibi ve bildirimleri
   - Sunucu bağlantısı kesildiğinde anında Snackbar bildirim gösterimi (3 saniye)

3. Kullanıcı Arayüzü:
   - Grid düzeni ile sunucuları görüntüleme (ayarlanabilir grid boyutu)
   - Açık/koyu tema desteği
   - Kategorilere göre gruplandırılmış bağlantılar
   - Bildirim paneli ile çevrimdışı sunucuları yönetme
   - Üst orta kısımda sunucu arama çubuğu (isim, adres, kullanıcı adı, açıklama veya kategoriye göre filtreleme)

4. Ayarlar:
   - Otomatik yenileme aralığı ayarları
   - Grid düzeninde satır başına düşen sunucu sayısı ayarı (varsayılan: 3)

VERİTABANI YAPISI
-----------------
SQLite veritabanı kullanılarak aşağıdaki tablolar oluşturulmuştur:

1. rdp_connections Tablosu:
   - id: INTEGER PRIMARY KEY AUTOINCREMENT
   - name: TEXT NOT NULL
   - hostname: TEXT NOT NULL
   - username: TEXT NOT NULL
   - password: TEXT NOT NULL
   - port: INTEGER NOT NULL
   - description: TEXT
   - category: TEXT DEFAULT 'Genel'

2. settings Tablosu:
   - id: INTEGER PRIMARY KEY
   - serversPerRow: INTEGER

BAĞIMLILIKLAR
-------------
Aşağıdaki Flutter paketleri kullanılmıştır:

- sqflite: SQLite veritabanı işlemleri için
- sqflite_common_ffi: Windows, Linux ve macOS desteği için
- intl: Dil ve tarih formatlamaları için
- path: Dosya yolları işlemleri için

KULLANIM
--------
1. Sağ alt köşedeki + butonu ile yeni RDP bağlantısı eklenebilir
2. Kategori ekleyerek bağlantılar organize edilebilir
3. Her sunucu kartı üzerindeki butonlar ile:
   - Sunucu durumu kontrol edilebilir
   - Bağlantı düzenlenebilir
   - Bağlantı silinebilir
4. Sunucu kartına tıklayarak RDP bağlantısı başlatılabilir
5. Üst kısımdaki arama çubuğunu kullanarak sunucuları isim, adres, kullanıcı adı, açıklama veya kategoriye göre arayabilirsiniz
6. Sağ üstteki ayarlar ikonu ile grid düzeni yapılandırılabilir
7. Sağ üstteki zamanlayıcı ile otomatik sunucu durumu kontrolü yapılandırılabilir 