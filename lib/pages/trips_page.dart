import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class ActivityPage2 extends StatefulWidget {
  const ActivityPage2({Key? key}) : super(key: key);

  @override
  _ActivityPageState createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage2> {
  List<Map<String, dynamic>> _fleteList = [];

  @override
  void initState() {
    super.initState();
    _getFletes();
  }

Future<void> _getFletes() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    DatabaseReference fletesRef = FirebaseDatabase.instance.reference().child("Fletes");
    Query fletesQuery = fletesRef.orderByChild("driverId").equalTo(user.uid);
    fletesQuery.onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map<dynamic, dynamic>) {
        List<Map<String, dynamic>> fletes = [];
        (event.snapshot.value as Map<dynamic, dynamic>).forEach((key, value) {
          // Solo agregar fletes con estado "Finalizado"
          if (value["state"] == "Finalizado") {
            fletes.add({"id": key, ...value});
          }
        });
        setState(() {
          _fleteList = fletes;
        });
      } else {
        print("No se encontraron fletes para el usuario con ID: ${user.uid}");
      }
    });
  } else {
    print("Usuario no logeado");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Fletes'),
      ),
      body: ListView.builder(
        itemCount: _fleteList.length,
        itemBuilder: (context, index) {
          Map<String, dynamic> flete = _fleteList[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FleteDetailsPage(flete: flete)),
              );
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Color.fromARGB(46, 255, 255, 255), // Cambiado el color de fondo
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                leading: Image.asset('assets/images/pack.png'), // Cambiado a una imagen proporcionada
                title: Text('My FleT'), // Cambiado el título
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4.0),
                    Text('Fecha: ${flete["date"] ?? ""}'), // Agregada la fecha
                    SizedBox(height: 4.0),
                    Text('Hora: ${flete["time"] ?? ""}'), // Agregada la hora
                    SizedBox(height: 4.0),
                    Text('Estado: ${flete["state"] ?? ""}'), // Agregado el estado
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios), // Icono agregado a la derecha
              ),
            ),
          );
        },
      ),
    );
  }
}
class FleteDetailsPage extends StatefulWidget {
  final Map<String, dynamic> flete;

  const FleteDetailsPage({Key? key, required this.flete}) : super(key: key);

  @override
  _FleteDetailsPageState createState() => _FleteDetailsPageState();
}

class _FleteDetailsPageState extends State<FleteDetailsPage> {
  Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController _mapController;
  late Set<Marker> _markers;
  late Set<Polyline> _polylines;
  late BitmapDescriptor _startMarkerIcon;
  late BitmapDescriptor _endMarkerIcon;

  @override
  void initState() {
    super.initState();
    _markers = {};
    _polylines = {};
    _loadMarkerIcons();
    _setRoute(widget.flete["startAddress"], widget.flete["endAddress"]);
  }

  Future<void> _loadMarkerIcons() async {
    final ByteData startBytes = await rootBundle.load('assets/images/paquete.png');
    final ByteData endBytes = await rootBundle.load('assets/images/casa.png');

    _startMarkerIcon = BitmapDescriptor.fromBytes(startBytes.buffer.asUint8List());
    _endMarkerIcon = BitmapDescriptor.fromBytes(endBytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final startAddress = widget.flete["startAddress"];
    final endAddress = widget.flete["endAddress"];

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Flete'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              margin: EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(0, 0),
                    zoom: 12,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                    _mapController = controller;
                    _loadCustomMapStyle();
                    _setRoute(widget.flete["startAddress"], widget.flete["endAddress"]);
                  },
                  markers: _markers,
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.fromARGB(36, 247, 247, 247).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Descripción:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${widget.flete["description"] ?? ""}',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Fecha:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${widget.flete["date"] ?? ""}',
                      style: TextStyle(
                        fontSize: 16,

                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Hora:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${widget.flete["time"] ?? ""}',
                      style: TextStyle(
                        fontSize: 16,

                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Estado:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${widget.flete["state"] ?? ""}',
                      style: TextStyle(
                        fontSize: 16,

                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Oferta:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\$${widget.flete["offerRate"] ?? ""}',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Dirección de Recogida:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '$startAddress',
                      style: TextStyle(
                        fontSize: 16,

                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Color.fromARGB(255, 253, 149, 23)),
                        SizedBox(width: 8),
                        Text(
                          'Dirección de Entrega:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '$endAddress',
                      style: TextStyle(
                        fontSize: 16,

                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _setRoute(String startAddress, String endAddress) async {
    List<Location> startPlacemark = await locationFromAddress(startAddress);
    List<Location> endPlacemark = await locationFromAddress(endAddress);

    LatLng startCoordinates = LatLng(startPlacemark[0].latitude!, startPlacemark[0].longitude!);
    LatLng endCoordinates = LatLng(endPlacemark[0].latitude!, endPlacemark[0].longitude!);

    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('start'),
          position: startCoordinates,
          icon: _startMarkerIcon,
        ),
      );
      _markers.add(
        Marker(
          markerId: MarkerId('end'),
          position: endCoordinates,
          icon: _endMarkerIcon,
        ),
      );
    });

    List<LatLng> route = await _getRouteCoordinates(startCoordinates, endCoordinates);

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: route,
          color: Color.fromARGB(255, 248, 220, 43),
          width: 5,
        ),
      );
    });

    _adjustCamera(startCoordinates, endCoordinates);
  }

  Future<List<LatLng>> _getRouteCoordinates(LatLng start, LatLng end) async {
    List<LatLng> coordinates = [];

    String apiUrl = "https://maps.googleapis.com/maps/api/directions/json?" +
        "origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&" +
        "mode=driving&" +
        "key=AIzaSyAABPjZ_hjwCFhSCMH9CwY2BCg4VbBZjRc";

    var response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      List<dynamic> routes = data["routes"];

      if (routes.isNotEmpty) {
        List<dynamic> legs = routes[0]["legs"];
        for (var leg in legs) {
          List<dynamic> steps = leg["steps"];
          for (var step in steps) {
            String points = step["polyline"]["points"];
            List<LatLng> decodedPolyline = _decodePoly(points);
            coordinates.addAll(decodedPolyline);
          }
        }
      }
    }

    return coordinates;
  }
  

  List<LatLng> _decodePoly(String poly) {
    List<LatLng> polyLineLatLong = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      LatLng position = LatLng(latitude, longitude);
      polyLineLatLong.add(position);
    }
    return polyLineLatLong;
  }

  void _adjustCamera(LatLng start, LatLng end) {
    double startLat = start.latitude;
    double startLng = start.longitude;
    double endLat = end.latitude;
    double endLng = end.longitude;

    double minLat = startLat < endLat ? startLat : endLat;
    double maxLat = startLat > endLat ? startLat : endLat;
    double minLng = startLng < endLng ? startLng : endLng;
    double maxLng = startLng > endLng ? startLng : endLng;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);
    _mapController.animateCamera(cameraUpdate);
  }

  Future<void> _loadCustomMapStyle() async {
    String style = await rootBundle.loadString('assets/themes/night_style.json');
    _mapController.setMapStyle(style);
  }
}

void main() {
  runApp(MaterialApp(
    home: ActivityPage2(),
  ));
}
