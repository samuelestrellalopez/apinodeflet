import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:driversapp2/authentication/login_screen.dart';
import 'package:driversapp2/methods/common_methods.dart';
import 'package:driversapp2/widgets/loading_dialog.dart';
import 'package:driversapp2/pages/profile_page.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  TextEditingController nametextEditingController = TextEditingController();
  TextEditingController surnametextEditingController = TextEditingController();
  TextEditingController emailtextEditingController = TextEditingController();
  TextEditingController passwordtextEditingController = TextEditingController();
  TextEditingController numbertextEditingController = TextEditingController();
  CommonMethods cMethods = CommonMethods();
  XFile? imageFile;
  String? urlOfUploadedImage;
  ValueNotifier<String?> urlNotifier = ValueNotifier<String?>(null);

  // Método para cargar la imagen desde Firebase Storage
  Future<String?> _loadImage(String? imageUrl) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance.ref().child("Images").child(imageUrl);
        final url = await ref.getDownloadURL();
        return url;
      } catch (e) {
        print("Error al cargar la imagen: $e");
        return null; // Puedes manejar este caso según sea necesario
      }
    }
    return null;
  }

  getUserInfoAndCheckBlockStatus() async {
    // Lógica para obtener datos del usuario y autocompletar campos
    DatabaseReference usersRef = FirebaseDatabase.instance
        .ref()
        .child("Drivers")
        .child(FirebaseAuth.instance.currentUser!.uid);

    await usersRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        setState(() {
          emailtextEditingController.text = (snap.snapshot.value as Map)["email"] ?? "";
          nametextEditingController.text = (snap.snapshot.value as Map)["name"] ?? "";
          surnametextEditingController.text = (snap.snapshot.value as Map)["surnames"] ?? "";
          numbertextEditingController.text = (snap.snapshot.value as Map)["number"] ?? "";
          urlOfUploadedImage = (snap.snapshot.value as Map)["photo"] ?? "";
          urlNotifier.value = urlOfUploadedImage;
        });
      } else {
        FirebaseAuth.instance.signOut();
        Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    getUserInfoAndCheckBlockStatus();
  }

  chooseImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imageFile = pickedFile;
      });
    }
  }

  chooseImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        imageFile = pickedFile;
      });
    }
  }

  updateProfile() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(messageText: "Guardando cambios..."),
    );

    try {
      // Verificar si se ha cargado una nueva imagen
      if (imageFile != null) {
        await uploadImageToStorage();
      }

      User? currentUser = FirebaseAuth.instance.currentUser;

      // Actualizar información del usuario en Firebase Authentication
      await currentUser!.verifyBeforeUpdateEmail(emailtextEditingController.text.trim());

      // Actualizar información del usuario en la base de datos de Firebase
      DatabaseReference usersRef = FirebaseDatabase.instance
          .ref()
          .child("Drivers")
          .child(currentUser.uid);

      Map<String, dynamic> updatedUserData = {
        "name": nametextEditingController.text.trim(),
        "surnames": surnametextEditingController.text.trim(),
        "number": numbertextEditingController.text.trim(),
        "photo": urlOfUploadedImage ?? "", // Usa la nueva URL o la existente
      };

      await usersRef.update(updatedUserData);

      Navigator.pop(context); // Cerrar diálogo de carga
      cMethods.displaySnackBar("Cambios guardados exitosamente", context);

      // Redirigir a la página de perfil después de guardar los cambios
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProfilePage()));
    } catch (error) {
      Navigator.pop(context); // Cerrar diálogo de carga
      if (error is FirebaseAuthException) {
        cMethods.displaySnackBar(error.message ?? 'Error desconocido', context);
      } else {
        cMethods.displaySnackBar('Error desconocido', context);
      }
    }
  }

  uploadImageToStorage() async {
    String imageIDName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference referenceImage =
        FirebaseStorage.instance.ref().child("Images").child(imageIDName);

    UploadTask uploadTask = referenceImage.putFile(File(imageFile!.path));
    TaskSnapshot snapshot = await uploadTask;
    urlOfUploadedImage = await snapshot.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Perfil"),
        automaticallyImplyLeading: false, // Esto quita el botón de retroceso
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20), // Aumenté el espaciado a 20
          child: Column(
            children: [
              const SizedBox(
                height: 20,
              ),

              ValueListenableBuilder<String?>(
                valueListenable: urlNotifier,
                builder: (context, value, child) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Seleccionar Imagen"),
                            content: SingleChildScrollView(
                              child: ListBody(
                                children: <Widget>[
                                  GestureDetector(
                                    child: const Text('Galería'),
                                    onTap: () {
                                      chooseImageFromGallery();
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  const Padding(padding: EdgeInsets.all(8.0)),
                                  GestureDetector(
                                    child: const Text('Tomar Foto'),
                                    onTap: () {
                                      chooseImageFromCamera();
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: CircleAvatar(
                      radius: 86,
                      backgroundImage: value != null
                          ? NetworkImage(value)
                          : AssetImage("assets/images/avatar_placeholder.png") as ImageProvider<Object>,
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                "Presiona para cambiar la imagen",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),

              // Campos de edición directa en la página
              const SizedBox(height: 20), // Espaciado de 20
              TextField(
                controller: nametextEditingController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 20), // Espaciado de 20
              TextField(
                controller: surnametextEditingController,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
              const SizedBox(height: 20), // Espaciado de 20
              TextField(
                controller: numbertextEditingController,
                decoration: const InputDecoration(labelText: 'Número de Teléfono'),
              ),

              // Botón para confirmar los cambios
              ElevatedButton(
                onPressed: () {
                  updateProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 88, vertical: 13),
                ),
                child: const Text(
                  "Confirmar Cambios",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
