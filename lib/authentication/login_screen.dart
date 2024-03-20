import 'package:driversapp2/pages/dashboard.dart';
import 'package:driversapp2/widgets/loading_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';


import '../methods/common_methods.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  TextEditingController emailtextEditingController = TextEditingController();
  TextEditingController passwordtextEditingController = TextEditingController();
  CommonMethods cMethods = CommonMethods();

    checkIfNetworkIsAvailable()
    {
      cMethods.checkConnectivity(context);
      
      signInFormValidation();
    }

  

    signInFormValidation()
    {
      if(!emailtextEditingController.text.trim().contains("@"))
      {
      cMethods.displaySnackBar("Ingresa un correo electronico valido", context);
      }
      else if (passwordtextEditingController.text.trim().length < 8)
      {
        cMethods.displaySnackBar("Tu contraseña debe coincidir con la del correo electronico", context);
      }
      else
      {
        signInUser();
      }
    }

    signInUser() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => LoadingDialog(messageText: "Iniciando sesión...")
  );

  try {
    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailtextEditingController.text.trim(),
      password: passwordtextEditingController.text.trim(),
    );

    final User? userFirebase = userCredential.user;

    if (userFirebase != null) {
      DatabaseReference usersRef = FirebaseDatabase.instance.ref().child("Drivers").child(userFirebase.uid);
      usersRef.once().then((snap) {
        if (snap.snapshot.value != null) {
          if ((snap.snapshot.value as Map)["blockStatus"] == "no") {
            //userEmail = (snap.snapshot.value as Map)["email"];
            Navigator.push(context, MaterialPageRoute(builder: (c) => Dashboard()));
          } else {
            FirebaseAuth.instance.signOut();
            cMethods.displaySnackBar(
              "Este usuario está bloqueado, contacta a soporte para más información: soporteflet@gmail.com",
              
              context,
            );
          }
        } else {
          FirebaseAuth.instance.signOut();
          cMethods.displaySnackBar("Este correo electrónico no está registrado", context);
        }
      });
    }
    
    // Aquí cerramos el diálogo de carga después de la autenticación exitosa
    Navigator.pop(context);
    
  } catch (error) {
    Navigator.pop(context);
    cMethods.displaySnackBar(error.toString(), context);
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
          children: [

            Image.asset(
              "assets/images/camion.png"
            ),

            Text(
              "Inicia sesión/Transportista",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            Text(
              "Llena los campos de abajo",
              style: TextStyle(
                fontSize: 14,
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

                const SizedBox(height: 22,),

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

                 
                   const SizedBox(height: 22,),

                   ElevatedButton(
              onPressed:()
              {
                checkIfNetworkIsAvailable();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 88,vertical: 13),
              ),
              child:  const Text(
                "Iniciar sesión",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              )
            ,),
          

           const SizedBox(height: 10,),


          GestureDetector(
            onTap:(){
              Navigator.push(context,
              MaterialPageRoute(builder: (context) =>SignUpScreen()),
              );
            },
          
           child: RichText(
              text: TextSpan(
              text: '¿No tienes cuenta? ',
            style: 
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            children: 
            <TextSpan>[
            TextSpan(
            text: 'Registrate!',
            style: 
            TextStyle(
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