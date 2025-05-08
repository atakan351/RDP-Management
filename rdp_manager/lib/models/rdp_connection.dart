class RdpConnection {
  final int? id;
  final String name;
  final String hostname;
  final String username;
  final String password;
  final int port;
  final String description;
  final String category;

  RdpConnection({
    this.id,
    required this.name,
    required this.hostname,
    required this.username,
    required this.password,
    this.port = 3389,
    this.description = '',
    this.category = 'Genel',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'username': username,
      'password': password,
      'port': port,
      'description': description,
      'category': category,
    };
  }

  factory RdpConnection.fromMap(Map<String, dynamic> map) {
    return RdpConnection(
      id: map['id'],
      name: map['name'],
      hostname: map['hostname'],
      username: map['username'],
      password: map['password'],
      port: map['port'],
      description: map['description'],
      category: map['category'] ?? 'Genel',
    );
  }

  RdpConnection copyWith({
    int? id,
    String? name,
    String? hostname,
    String? username,
    String? password,
    int? port,
    String? description,
    String? category,
  }) {
    return RdpConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
      description: description ?? this.description,
      category: category ?? this.category,
    );
  }
}
