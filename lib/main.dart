import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ListUserDataPage(),
    );
  }
}

class ListUserDataPage extends StatefulWidget {
  const ListUserDataPage({super.key});

  @override
  State<ListUserDataPage> createState() => _ListUserDataPageState();
}
class UserModel {
  int? id;
  String nama = '';
  int umur = 0;
  
  UserModel({this.id, required this.nama, required this.umur});
}

class _ListUserDataPageState extends State<ListUserDataPage> {
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _umurCtrl = TextEditingController();
 
  List<UserModel> userList = [
    UserModel(id: 1, nama: 'atu', umur: 10),
    UserModel(id: 2, nama: 'ua', umur: 9),
    UserModel(id: 3, nama: 'iga', umur: 8),
    UserModel(id: 4, nama: 'mpat', umur: 7),
    UserModel(id: 5, nama: 'ima', umur: 6),
  ];

  void _form(int? id) {
    if(id != null){
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
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20 , 20, 20, MediaQuery.of(context).viewInsets.bottom + 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaCtrl,
              decoration: InputDecoration(hintText: "Nama"),
            ),
            TextField(
              controller: _umurCtrl,
              decoration: InputDecoration(hintText: "Umur"),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: () {
                final nama = _namaCtrl.text.trim();
                final umur = int.tryParse(_umurCtrl.text) ?? 0;
                if (nama.isNotEmpty && umur > 0) {
                  _save(id, nama, umur);
                }
              },
              child: Text(id == null ? 'Tambah' : 'Perbarui'),
            ),
          ],
        ),
      ),
    );
  }

  void _save(int? id, String nama, int umur) {
    if(id != null){
      var user = userList.firstWhere((data) => data.id== id);
      setState(() {
        user.nama = nama;
        user.umur = umur;
      });
 
    } else {
    var nextId = userList.length + 1;
    var newUser = UserModel(id: nextId , nama: nama, umur: umur);
    setState(() {
      userList.add(newUser);
   });
   Navigator.pop(context);
    }
  }
   

  void _delete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Hapus'),
        content: Text('Apakah anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(context);
          }, 
          child: Text('Batal')),
          TextButton(onPressed: () {
            setState(() {
               userList.removeWhere((data) => data.id == id);
               Navigator.pop(context);
            });
          }, child: Text('Hapus')),
            
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User List'),
      ),
      body: ListView.builder(
        itemCount: userList.length,
        itemBuilder: (cxt, i) { 
          return ListTile(
            title: Text(userList[i].nama),
            subtitle: Text('Umur: ${userList[i].umur} tahun '),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => _form(userList[i].id), 
                child: Icon(Icons.edit)),
                TextButton(onPressed: () => _delete(userList[i].id!),
                child: Icon(Icons.delete)),
              ],
            ),
          );
        },
      ),
    floatingActionButton: FloatingActionButton(
        onPressed: () => _form(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}