class AppSettings {
  final int serversPerRow;

  AppSettings({
    this.serversPerRow = 3,
  });

  AppSettings copyWith({
    int? serversPerRow,
  }) {
    return AppSettings(
      serversPerRow: serversPerRow ?? this.serversPerRow,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serversPerRow': serversPerRow,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serversPerRow: map['serversPerRow'] ?? 3,
    );
  }
}
