import 'package:driversapp2/pages/updateprofile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'package:driversapp2/authentication/login_screen.dart';
import 'package:driversapp2/global/global_variables.dart';
import 'package:driversapp2/methods/common_methods.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  CommonMethods cMethods = CommonMethods();

  late String userEmail = "";
  late String userName = "";
  late String userSurname = "";
  late String userPhotoUrl = "";

  getUserInfoAndCheckBlockStatus() async {
    DatabaseReference usersRef = FirebaseDatabase.instance
        .ref()
        .child("Drivers")
        .child(FirebaseAuth.instance.currentUser!.uid);

    await usersRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        if ((snap.snapshot.value as Map)["blockStatus"] == "no") {
          setState(() {
            userEmail = (snap.snapshot.value as Map)["email"] ?? "";
            userName = (snap.snapshot.value as Map)["name"] ?? "";
            userSurname = (snap.snapshot.value as Map)["surnames"] ?? "";
            userPhotoUrl = (snap.snapshot.value as Map)["photo"] ?? "";
          });
        } else {
          FirebaseAuth.instance.signOut();
          Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
          cMethods.displaySnackBar(
            "Este usuario está bloqueado, contacta a soporte para más información: soporteflet@gmail.com",
            context,
          );
        }
      } else {
        FirebaseAuth.instance.signOut();
        Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
      }
    });
  }

  // Método para cargar la imagen desde Firebase Storage
  Future<String> _loadImage() async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.refFromURL(userPhotoUrl);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print("Error al cargar la imagen: $e");
      return "";
    }
  }

  @override
  void initState() {
    super.initState();
    getUserInfoAndCheckBlockStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil"),
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _loadImage(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(snapshot.data ?? ""),
                  );
                } else {
                  return CircleAvatar(
                    radius: 50,
                    
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Nombre: $userName $userSurname',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Correo Electrónico: $userEmail',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProfilePage()),
                );
              },
              child: Text('Editar Perfil'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Lógica para editar la información del automóvil
                // Puedes abrir un nuevo formulario o una pantalla de edición aquí
              },
              child: Text('Editar Automóvil'),
            ),
          ],
        ),
      ),
    );
  }
}
