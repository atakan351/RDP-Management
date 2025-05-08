RDP Yöneticisi

RDP Yöneticisi, Windows, Linux ve macOS ortamlarında çalışan, uzak masaüstü bağlantılarını (RDP) yönetmek için geliştirilmiş bir Flutter tabanlı masaüstü uygulamasıdır. Uygulama, RDP bağlantılarını kategorilere ayırmanıza, düzenlemenize, silmenize ve kolayca başlatmanıza imkan tanır.



Özellikler

✉️ Bağlantı Yönetimi

RDP bağlantıları ekle, düzenle ve sil

Bağlantıları kategorilere ayır ve listele

Tek tıkla bağlantı başlatma

⚡ Sunucu Durumu Takibi

Manuel/otomatik sunucu erişilebilirlik kontrolü

Çevrimdışı sunucular için anında snackbar bildirimi

Çevrimdışı kalma sürelerini kaydetme

🔍 Arayüz ve Kullanım

Grid düzeniyle sunucu kartları (kendi satır sayını ayarlayabilirsin)

Karanlık/açık tema

Sunucu kartında bağlantı test, düzenleme, silme butonları

İsim, adres, açıklama veya kategoriye göre filtreleme

⚙ Ayarlar

Otomatik yenileme aralığı belirleme

Grid satır başı sunucu sayısı ayarlama

Teknik Bilgiler

Kullanılan Teknolojiler

Dart 3.x

Flutter (cross-platform UI toolkit)

SQLite (sqflite & sqflite_common_ffi)

Platformlar: Windows, Linux, macOS

Mimari Yapı

MVC benzeri yapı

RdpConnection, AppSettings modelleri

DatabaseService, RdpService, PingService servisleri

Bağımlılıklar

sqflite, sqflite_common_ffi, intl, path

Kurulum ve Kullanım

Uygulamayı çalıştır

+ butonuyla yeni bağlantı ekle

Kategori seçerek bağlantıları grupla

Kartlara tıklayarak bağlantı başlat

Ayarlar menüsünden grid düzenini ayarla

Lisans

MIT Lisansı

RDP Manager

RDP Manager is a cross-platform Flutter application designed to manage Remote Desktop (RDP) connections on Windows, Linux, and macOS. It allows users to categorize, organize, test, and launch multiple RDP connections from a single interface.

Features

🚀 RDP Connection Management

Add, edit, delete connections

Categorize and display them in grid view

One-click launch support

🔧 Server Monitoring

Manual/automatic server reachability check

Real-time offline notifications (Snackbar)

Offline duration tracking

🔍 User Interface

Customizable grid layout

Dark/light mode

Quick filtering by name, address, username, description, or category

Inline buttons for test/edit/delete on each server card

⚙ Settings

Set server auto-refresh interval

Set number of servers per row

Technical Overview

Technologies Used

Dart 3.x

Flutter (Desktop apps)

SQLite with sqflite and sqflite_common_ffi

Platforms: Windows, Linux, macOS

Architecture

MVC-style pattern

RdpConnection, AppSettings models

DatabaseService, RdpService, PingService modules

Dependencies

sqflite, sqflite_common_ffi, intl, path

How to Use

Run the application

Add new connections via the + button

Organize them using categories

Click a card to initiate RDP session

Customize the grid layout from settings

License

MIT License
