import 'package:flutter/material.dart';
import '../models/rdp_connection.dart';
import '../services/database_service.dart';

class RdpFormScreen extends StatefulWidget {
  final RdpConnection? connection;

  const RdpFormScreen({Key? key, this.connection}) : super(key: key);

  @override
  State<RdpFormScreen> createState() => _RdpFormScreenState();
}

class _RdpFormScreenState extends State<RdpFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '3389');
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Genel');

  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  List<String> _categories = ['Genel']; // Önceden var olan kategoriler
  String _selectedCategory = 'Genel';
  bool _isNewCategory = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.connection != null) {
      _nameController.text = widget.connection!.name;
      _hostnameController.text = widget.connection!.hostname;
      _usernameController.text = widget.connection!.username;
      _passwordController.text = widget.connection!.password;
      _portController.text = widget.connection!.port.toString();
      _descriptionController.text = widget.connection!.description;
      _selectedCategory = widget.connection!.category;
      _categoryController.text = _selectedCategory;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseService.getCategories();

      // Set ile tekrar eden kategorileri temizle
      final uniqueCategories =
          Set<String>.from(categories.isNotEmpty ? categories : ['Genel'])
              .toList();

      setState(() {
        _categories = uniqueCategories;

        // Eğer widget düzenleme modundaysa ve kategorisi varsa
        if (widget.connection != null) {
          _selectedCategory = widget.connection!.category;

          // Seçili kategori listede yoksa ekleyelim
          if (!_categories.contains(_selectedCategory)) {
            _categories.add(_selectedCategory);
          }
        } else {
          // Yeni bağlantı oluşturuluyorsa ve kategoriler yüklendiyse
          // seçili kategorinin listede olduğunu kontrol et
          if (_categories.isNotEmpty &&
              !_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories[0]; // İlk kategoriyi seç
          }
        }
      });
    } catch (e) {
      // Kategori yükleme hatası - varsayılana devam et
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategoriler yüklenirken hata: $e')),
        );
      }
    }
  }

  Future<void> _saveConnection() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Kategori belirleme
        String category =
            _isNewCategory ? _categoryController.text : _selectedCategory;
        if (category.trim().isEmpty) {
          category = 'Genel';
        }

        final connection = RdpConnection(
          id: widget.connection?.id,
          name: _nameController.text,
          hostname: _hostnameController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          port: int.parse(_portController.text),
          description: _descriptionController.text,
          category: category,
        );

        if (widget.connection == null) {
          await _databaseService.addConnection(connection);
        } else {
          await _databaseService.updateConnection(connection);
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connection == null
            ? 'Yeni RDP Bağlantısı'
            : 'RDP Bağlantısını Düzenle'),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Bağlantı Adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir bağlantı adı girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostnameController,
                      decoration: const InputDecoration(
                        labelText: 'Sunucu Adresi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir sunucu adresi girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir port numarası girin';
                        }
                        final port = int.tryParse(value);
                        if (port == null || port <= 0 || port > 65535) {
                          return 'Geçerli bir port numarası girin (1-65535)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir kullanıcı adı girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir şifre girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Kategori seçimi
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.category, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Kategori',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Yeni Kategori'),
                                  onPressed: () {
                                    setState(() {
                                      _isNewCategory = !_isNewCategory;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _isNewCategory
                                ? TextFormField(
                                    controller: _categoryController,
                                    decoration: const InputDecoration(
                                      labelText: 'Yeni Kategori Adı',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.create_new_folder),
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value:
                                        _categories.contains(_selectedCategory)
                                            ? _selectedCategory
                                            : _categories.isNotEmpty
                                                ? _categories[0]
                                                : 'Genel',
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.folder),
                                    ),
                                    items: _categories.map((category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedCategory = value;
                                        });
                                      }
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (İsteğe Bağlı)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saveConnection,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.connection == null
                            ? 'Bağlantı Oluştur'
                            : 'Bağlantıyı Güncelle',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
