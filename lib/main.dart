import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ListUserDataPage());
  }
}

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String dbPath = path.join(await getDatabasesPath(), 'user_data.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        return db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT,
            umur INTEGER
          )
        ''');
      },
    );
  }

  static Future<int> insertData(UserModel userModel) async {
    final db = await database;
    return await db.insert(
      'users',
      userModel.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<UserModel>> getData() async {
    final db = await database;
    List<Map<String, Object?>> result = await db.query('users');
    return result.map((userMap) => UserModel.fromJson(userMap)).toList();
  }

  static Future<int> updateData(int id, UserModel userModel) async {
    final db = await database;
    var user = userModel.toJson()..remove('id');
    return await db.update('users', user, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteData(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}

class UserModel {
  int? id;
  String nama = '';
  int umur = 0;

  UserModel({this.id, required this.nama, required this.umur});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(id: json['id'], nama: json['nama'], umur: json['umur']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nama': nama, 'umur': umur};
  }
}

class ListUserDataPage extends StatefulWidget {
  const ListUserDataPage({super.key});

  @override
  State<ListUserDataPage> createState() => _ListUserDataPageState();
}

class _ListUserDataPageState extends State<ListUserDataPage> {
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _umurCtrl = TextEditingController();

  List<UserModel> userList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _reloadData();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _umurCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var users = await DatabaseHelper.getData();
      if (!mounted) return;
      setState(() {
        userList = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error: ${e.toString()}');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _form(int? id) {
    if (id != null) {
      var user = userList.firstWhere((data) => data.id == id);
      _namaCtrl.text = user.nama;
      _umurCtrl.text = user.umur.toString();
    } else {
      _namaCtrl.clear();
      _umurCtrl.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              id == null ? 'Tambah Data Pengguna' : 'Edit Data Pengguna',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _namaCtrl,
              decoration: InputDecoration(
                hintText: "Nama",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _umurCtrl,
              decoration: InputDecoration(
                hintText: "Umur",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final nama = _namaCtrl.text.trim();
                  final umur = int.tryParse(_umurCtrl.text) ?? 0;
                  if (nama.isEmpty) {
                    _showSnackBar('Nama tidak boleh kosong');
                    return;
                  }
                  if (umur <= 0) {
                    _showSnackBar('Umur harus lebih dari 0');
                    return;
                  }
                  await _save(id, nama, umur);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _showSnackBar(
                      id == null
                          ? 'Data berhasil ditambah'
                          : 'Data berhasil diupdate',
                    );
                  }
                },
                child: Text(id == null ? 'Tambah' : 'Perbarui'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(int? id, String nama, int umur) async {
    try {
      var newUser = UserModel(nama: nama, umur: umur);
      if (id != null) {
        await DatabaseHelper.updateData(id, newUser);
      } else {
        await DatabaseHelper.insertData(newUser);
      }
      await _reloadData();
    } catch (e) {
      _showSnackBar('Gagal menyimpan data: ${e.toString()}');
    }
  }

  void _delete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.deleteData(id);
                if (ctx.mounted) Navigator.pop(ctx);
                await _reloadData();
                _showSnackBar('Data berhasil dihapus');
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnackBar('Gagal menghapus: ${e.toString()}');
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Pengguna'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userList.isEmpty
          ? const Center(
              child: Text(
                'Belum ada data\nTambahkan dengan tombol + di bawah',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: userList.length,
              itemBuilder: (cxt, i) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      userList[i].nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Umur: ${userList[i].umur} tahun'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _form(userList[i].id),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _delete(userList[i].id!),
                          tooltip: 'Hapus',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(null),
        tooltip: 'Tambah Data',
        child: const Icon(Icons.add),
      ),
    );
  }
}
