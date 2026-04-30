import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';

void main() {
  // Initialize FFI for web support without a shared worker.
  // This avoids the need to ship the worker binary file.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter SQLite Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ListUserDataPage(),
    );
  }
}


class UserModel {
  int? id;
  String nama;
  int umur;

  UserModel({this.id, required this.nama, required this.umur});

  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"],
      nama: json["nama"],
      umur: json["umur"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "nama": nama,
      "umur": umur,
    };
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
    String path;
    if (kIsWeb) {
      path = 'user_db.db';
    } else {
      path = p.join(await getDatabasesPath(), "user_db.db");
    }
    print("Initializing database at path: $path");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        print("Creating table users");
        return db.execute(
            "CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT, umur INTEGER)");
      },
    );
  }


  static Future<int> insertData(UserModel user) async {
    final db = await database;
    print("Inserting into database: ${user.nama}");
    return await db.insert(
      "users",
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  static Future<List<UserModel>> getData() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query("users");
    print("Queried ${result.length} users from database");
    return result.map((userMap) => UserModel.fromJson(userMap)).toList();
  }


  static Future<int> updateData(int id, UserModel userModel) async {
    final db = await database;
    var data = userModel.toJson();
    data.remove('id'); // Menghapus ID agar tidak terjadi konflik saat update

    return await db.update("users", data, where: "id = ?", whereArgs: [id]);
  }

  
  static Future<int> deleteData(int id) async {
    final db = await database;
    return await db.delete("users", where: "id = ?", whereArgs: [id]);
  }
}

// --- UI PAGE ---
class ListUserDataPage extends StatefulWidget {
  const ListUserDataPage({super.key});

  @override
  State<ListUserDataPage> createState() => _ListUserDataPageState();
}

class _ListUserDataPageState extends State<ListUserDataPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _umurCtrl = TextEditingController();

  List<UserModel> userList = [];

  @override
  void initState() {
    super.initState();
    _reloadData(); 
  }


  void _reloadData() async {
    try {
      var users = await DatabaseHelper.getData();
      print("Loaded users: ${users.length}");
      setState(() {
        userList = users;
      });
    } catch (e) {
      print("Error loading data: $e");
    }
  }


  void _form(int? id) {
    if (id != null) {
      var user = userList.firstWhere((data) => data.id == id);
      _nameCtrl.text = user.nama;
      _umurCtrl.text = user.umur.toString();
    } else {
      _nameCtrl.clear();
      _umurCtrl.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: "Nama")),
            TextField(
              controller: _umurCtrl,
              decoration: const InputDecoration(hintText: "Umur"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.isNotEmpty && _umurCtrl.text.isNotEmpty) {
                  _save(id, _nameCtrl.text, int.parse(_umurCtrl.text));
                }
              },
              child: Text(id == null ? "Tambah" : "Perbaharui"),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi Simpan (Insert atau Update)
  void _save(int? id, String nama, int umur) async {
    try {
      if (id != null) {
        await DatabaseHelper.updateData(id, UserModel(nama: nama, umur: umur));
        print("Data updated: $nama, $umur");
      } else {
        await DatabaseHelper.insertData(UserModel(nama: nama, umur: umur));
        print("Data inserted: $nama, $umur");
      }

      _reloadData(); // Refresh list di layar utama
      if (mounted) Navigator.pop(context); // Tutup Bottom Sheet
    } catch (e) {
      print("Error saving data: $e");
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: Text("Failed to save data: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  // Fungsi Hapus dengan Dialog Konfirmasi
  void _delete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Apakah anda yakin ingin menghapus data ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.deleteData(id);
              _reloadData();
              if (mounted) Navigator.pop(context); // Tutup Dialog
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User List"),
      ),
      body: userList.isEmpty
          ? const Center(child: Text("Data kosong. Klik + untuk menambah."))
          : ListView.builder(
              itemCount: userList.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(userList[i].nama),
                subtitle: Text("Umur: ${userList[i].umur} tahun"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _form(userList[i].id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _delete(userList[i].id!),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
