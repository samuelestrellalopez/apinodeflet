import 'dart:io';

import 'package:driversapp2/authentication/login_screen.dart';
import 'package:driversapp2/pages/dashboard.dart';
import 'package:driversapp2/widgets/loading_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:driversapp2/methods/common_methods.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'; 



//REGISTRO DE USUARIO


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  CommonMethods cMethods = CommonMethods();
  //Usuario
String urlOfUploadedImage = "";
TextEditingController emailtextEditingController = TextEditingController();
TextEditingController nametextEditingController = TextEditingController();
TextEditingController surnametextEditingController = TextEditingController();
TextEditingController passwordtextEditingController = TextEditingController();
TextEditingController confirmpasswordtextEditingController =
    TextEditingController();
TextEditingController numbertextEditingController = TextEditingController();
//Coche
TextEditingController vehicleColorTextEditingController =
    TextEditingController();
TextEditingController vehicleModelTextEditingController =
    TextEditingController();
TextEditingController vehiclePlateNumberTextEditingController =
    TextEditingController();
XFile? imageFile;

  checkIfNetworkIsAvailable() {
    cMethods.checkConnectivity(context);
    if(imageFile != null)
    {
      signUpFormValidation();
    }
    else
    {
      cMethods.displaySnackBar("Por favor elige una foto de perfil", context);
    }
    
  }

  signUpFormValidation() {
    if (!emailtextEditingController.text.trim().contains("@")) {
      cMethods.displaySnackBar("Ingresa un correo electronico valido", context);
    } else if (passwordtextEditingController.text.trim().length < 8) {
      cMethods.displaySnackBar(
          "Tu contraseña debe de contener al menos 8 caracteres", context);
    } else if (confirmpasswordtextEditingController.text !=
        passwordtextEditingController.text) {
      cMethods.displaySnackBar(
          "Asegurate de que tu contraseña coincida con la contraseña proporcionada",
          context);
    } else if (numbertextEditingController.text.trim().length < 8) {
      cMethods.displaySnackBar("Ingresa un número de telefono válido", context);

    }else if (vehicleModelTextEditingController.text.trim().isEmpty ||
        vehicleColorTextEditingController.text.trim().isEmpty ||
        vehiclePlateNumberTextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackBar(
          "Por favor, completa todos los campos del automóvil", context);
    }
     else {
       uploadImageToStorage();

    }
  }
Future<void> chooseImageFromGalleryOrCamera() async {
  final ImagePicker _picker = ImagePicker();
  final XFile? pickedFile = await showDialog<XFile>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Seleccionar Imagen"),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final XFile? pickedGalleryFile = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    Navigator.of(context).pop(pickedGalleryFile);
                  },
                  child: Text('Seleccionar de la Galería'),
                ),
              ),
              SizedBox(height: 10), // Espacio entre los botones
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Permite al usuario tomar una foto directamente
                    final XFile? pickedCameraFile = await _picker.pickImage(
                      source: ImageSource.camera,
                    );
                    Navigator.of(context).pop(pickedCameraFile);
                  },
                  child: Text('Tomar Foto'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (pickedFile != null) {
    setState(() {
      imageFile = pickedFile;
    });
  }
}



  uploadImageToStorage() async {
    String imageIDName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference referenceImage = FirebaseStorage.instance.ref().child("Images").child(imageIDName);

    UploadTask uploadTask = referenceImage.putFile(File(imageFile!.path));
    TaskSnapshot snapshot = await uploadTask;
    urlOfUploadedImage = await snapshot.ref.getDownloadURL();

    setState(() {
      urlOfUploadedImage;
    });
    registerNewUserWithCar();
  }

  registerNewUserWithCar() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(messageText: "Registrando tu cuenta..."),
    );
    final User? userFirebase = (
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: emailtextEditingController.text.trim(),
                password: passwordtextEditingController.text.trim()
                ).catchError((errorMsg) 
                {
      Navigator.pop(context);
      cMethods.displaySnackBar(errorMsg.toString(), context);
    })).user;

    if (!context.mounted) return;
    Navigator.pop(context);

    DatabaseReference usersRef = FirebaseDatabase.instance
        .ref()
        .child("Drivers")
        .child(userFirebase!.uid);
        

    Map driverCarInfo = {
      "carColor": vehicleColorTextEditingController.text.trim(),
      "carModel": vehicleModelTextEditingController.text.trim(),
      "carPlateNumber": vehiclePlateNumberTextEditingController.text.trim(),
    };
    Map driverDataMap = {
      "photo": urlOfUploadedImage,
      "name": nametextEditingController.text.trim(),
      "surnames": surnametextEditingController.text.trim(),
      "email": emailtextEditingController.text.trim(),
      "number": numbertextEditingController.text.trim(),
      "id": userFirebase.uid,
      "car_details": driverCarInfo,
      "blockStatus": "no",
    };
    usersRef.set(driverDataMap);

    Navigator.push(context, MaterialPageRoute(builder: (c) => Dashboard()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const SizedBox(
                height: 40,
              ),

              imageFile == null
                  ? CircleAvatar(
                      radius: 86,
                      backgroundImage:
                          AssetImage("assets/images/avatarman.png"),
                    )
                  : Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                        image: DecorationImage(
                          fit: BoxFit.fitHeight,
                          image: FileImage(
                            File(
                              imageFile!.path,
                            ),
                          ),
                        ),
                      ),
                    ),

              const SizedBox(
                height: 22,
              ),

              GestureDetector(
                onTap: () {
                  chooseImageFromGalleryOrCamera();
                },
                child: const Text(
                  "Selecciona una imagen",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                "Llena los campos de abajo",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              //Text fields and Button
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    TextField(
                      controller: emailtextEditingController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Correo electrónico",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "usuario@correo.com",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: nametextEditingController,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        labelText: "Nombre/s",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: surnametextEditingController,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        labelText: "Apellido/s",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: numbertextEditingController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Número de telefono",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "12345678",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: passwordtextEditingController,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        labelStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: confirmpasswordtextEditingController,
                      obscureText: true,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        labelText: "Repite tu contraseña",
                        labelStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),


                    TextField(
                      controller: vehicleModelTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Modelo del coche",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "Aveo/Golf/etc...",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: vehicleColorTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Color del coche",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "Rojo/Azul/Amarillo/etc...",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    TextField(
                      controller: vehiclePlateNumberTextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Placas del coche",
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: "",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 194, 103),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        checkIfNetworkIsAvailable();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding:
                            EdgeInsets.symmetric(horizontal: 88, vertical: 13),
                      ),
                      child: const Text(
                        "Registrarse",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),


                   
                    const SizedBox(
                      height: 10,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LoginScreen()),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          text: '¿Ya tienes una cuenta? ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: 'Inicia sesión',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );


}
}