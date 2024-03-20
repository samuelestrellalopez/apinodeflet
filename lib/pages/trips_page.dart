import 'package:flutter/material.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({Key? key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final List<Map<String, String>> _acceptedTrips = [
    {
      'description': 'Viaje 1',
      'startAddress': 'Dirección de inicio 1',
      'endAddress': 'Dirección de entrega 1',
      'date': 'Fecha 1',
    },
    {
      'description': 'Viaje 2',
      'startAddress': 'Dirección de inicio 2',
      'endAddress': 'Dirección de entrega 2',
      'date': 'Fecha 2',
    },
    // Agrega más datos de fletes aceptados según sea necesario
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fletes Aceptados'),
        automaticallyImplyLeading: false, // No muestra el botón de retroceso
      ),
      backgroundColor: Colors.black, // Fondo negro
      body: ListView.builder(
        itemCount: _acceptedTrips.length,
        itemBuilder: (context, index) {
          final trip = _acceptedTrips[index];
          return Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[900], // Fondo gris oscuro
            child: ListTile(
              title: Text(
                trip['description'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange, // Texto naranja
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    'Inicio: ${trip['startAddress'] ?? ''}',
                    style: TextStyle(color: Colors.orange), // Texto naranja
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Destino: ${trip['endAddress'] ?? ''}',
                    style: TextStyle(color: Colors.orange), // Texto naranja
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Fecha: ${trip['date'] ?? ''}',
                    style: TextStyle(color: Color.fromARGB(255, 255, 164, 28)), // Texto naranja
                  ),
                  SizedBox(height: 4),
                ],
              ),
              onTap: () {
                // Aquí puedes agregar la lógica para navegar a los detalles del viaje
              },
            ),
          );
        },
      ),
    );
  }
}
