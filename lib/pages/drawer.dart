import 'package:driversapp2/authentication/login_screen.dart';
import 'package:driversapp2/pages/earnings_page.dart';
import 'package:driversapp2/pages/profile_page.dart';
import 'package:driversapp2/pages/trips_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DrawerWidget extends StatelessWidget {
  const DrawerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    String? uid = user?.uid;

    return FutureBuilder<DataSnapshot>(
      future: _loadDriverInfo(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          var driverData = snapshot.data!.value as Map<dynamic, dynamic>;
          String? name = driverData['name'];
          String? surnames = driverData['surnames'];
          String? photoUrl = driverData['photoUrl'];

          return FutureBuilder<String>(
            future: _loadDriverImage(uid),
            builder: (context, imageSnapshot) {
              if (imageSnapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (imageSnapshot.hasError) {
                return Text('Error: ${imageSnapshot.error}');
              } else {
                String? photoUrl = imageSnapshot.data;

                return Drawer(
                  child: Container(
                    color: Color.fromARGB(255, 187, 187, 187),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(bottom: 16), // Espacio adicional debajo del avatar
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.orange, // Cambia el color de fondo del avatar a naranja
                                  backgroundImage: NetworkImage(photoUrl ?? ''),
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, // Asegura que el contenedor tenga forma de círculo
                                  border: Border.all(
                                    color: Colors.white, // Color del borde blanco
                                    width: 3, // Ancho del borde
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2), // Sombra con opacidad
                                      spreadRadius: 2,
                                      blurRadius: 3,
                                      offset: Offset(0, 2), // Desplazamiento de la sombra
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '¡Bienvenido!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$name $surnames', // Mostrar nombre y apellidos
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              color: Color.fromARGB(255, 37, 37, 37),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.home_filled, color: Color.fromARGB(255, 255, 255, 255)),
                                    title: Text('Inicio', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                                    onTap: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.wallet, color: Color.fromARGB(255, 255, 255, 255)),
                                    title: Text('Ganancias', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => EarningsPage()));
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.local_shipping, color: Color.fromARGB(255, 255, 255, 255)),
                                    title: Text('Viajes', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => ActivityPage2()));
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.account_circle, color: Color.fromARGB(255, 255, 255, 255)),
                                    title: Text('Perfil', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => ProfilePage()));
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.read_more_rounded, color: Color.fromARGB(255, 255, 255, 255)),
                                    title: Text('Más', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                                    onTap: () {
                                      // Implementar lógica para la opción 'Más'
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.exit_to_app, color: Color.fromARGB(255, 255, 255, 255)),
                                    title: Text('Salir', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          );
        }
      },
    );
  }

  Future<DataSnapshot> _loadDriverInfo(String? uid) async {
    DatabaseReference driverRef = FirebaseDatabase.instance
        .reference()
        .child("Drivers")
        .child(uid ?? '');

    DataSnapshot snapshot;
    try {
      DatabaseEvent event = await driverRef.once();
      snapshot = event.snapshot;
    } catch (e) {
      print("Error al cargar la información del conductor: $e");
      rethrow;
    }

    return snapshot;
  }


  Future<String> _loadDriverImage(String? uid) async {
   try {
    DatabaseReference userRef = FirebaseDatabase.instance
        .ref()
        .child("Drivers")
        .child(FirebaseAuth.instance.currentUser!.uid);

    // Utiliza el método once().then() para obtener el DataSnapshot del evento
    DataSnapshot snapshot = await userRef.once().then((event) {
      return event.snapshot;
    });

    if (snapshot.value != null) {
      // Obtén la URL de la imagen del conductor desde los datos obtenidos
      String? photoUrl = (snapshot.value as Map)["photo"];
      return photoUrl ?? ""; // Devuelve la URL de la imagen o una cadena vacía si no hay URL disponible
    } else {
      print("No se encontraron datos para el conductor.");
      return ""; // Devuelve una cadena vacía si no se encontraron datos
    }
  } catch (e) {
    print("Error al cargar la imagen del conductor: $e");
    return ""; // Devuelve una cadena vacía en caso de error
  }
}
}
