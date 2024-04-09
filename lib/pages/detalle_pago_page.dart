import 'package:driversapp2/pages/home_page.dart';
import 'package:flutter/material.dart';

class DetallePagoPage extends StatelessWidget {
  final double offerRate;

  const DetallePagoPage({Key? key, required this.offerRate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 350, // Aumenta el ancho del contenedor
              height: 560, // Aumenta la altura del contenedor
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(30), // Aumenta el radio de borde para hacerlo más grande
              ),
              child: Center(
                child: Text(
                  '\$$offerRate', // Cambia el texto para mostrar el precio
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white), // Aumenta el tamaño y establece el color blanco
                ),
              ),
            ),
            SizedBox(height: 60), // Aumenta el espacio entre el contenedor y el botón
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 60, vertical: 24), // Aumenta el tamaño del botón
                textStyle: TextStyle(fontSize: 20, color: Colors.white), // Establece el color del texto como blanco
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Ajusta el radio del borde del botón
                ),
              ),
              onPressed: () {
                // Navega de regreso a la página de inicio al presionar el botón
                Navigator.push(context, MaterialPageRoute(builder: (c) => HomePage()));
              },
              child: Text('Flete Cobrado'),
            ),
          ],
        ),
      ),
    );
  }
}
