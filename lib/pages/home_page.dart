import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:driversapp2/pages/detalle_pago_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:driversapp2/pages/drawer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
    home: HomePage(),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key});

  @override
  State<HomePage> createState() => _HomePageState();
  
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _googleMapControllerCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _googleMapController;
  Position? _currentPositionOfUser;
  Set<Marker> _markers = {};
  bool _showTriangularWindow = false;
  User? _currentUser;
  List<dynamic> _allFletes = [];
  List<dynamic> _pendingFletes = [];
  Set<Polyline> _polylines = {};
  bool _showStartTripButton = false; // Variable para controlar la visibilidad del botón
    bool _showStartTripButton2 = false; // Variable para controlar la visibilidad del botón

  LatLng? _lastCameraPosition;
  Map<dynamic, dynamic>? _selectedFleteInfo;
  StreamSubscription<Position>? _positionStream; // Declarar la variable miembro
bool _tripStarted = false; // Variable para controlar si el viaje ha comenzado
bool _showFletesPendientesButton = true;

  bool _showContinueToDeliveryButton = false; // Variable para controlar la visibilidad del botón "Continuar a la entrega"
  bool _showDashboard = true; // Estado para controlar la visibilidad del Dashboard
bool _showFinishDeliveryButton = false;
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
bool _showProfileImage = true; // Inicialmente visible
bool _showDriverPhoto = true; // Variable para controlar la visibilidad de la foto del conductor
bool _showContinueToDeliveryButton2 = false;

StreamController<LatLng> _driverLocationStreamController = StreamController<LatLng>();

  @override
  void initState() {
    super.initState();
    _initializeCurrentUser();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _getFletesFromFirebase();
      
    });
    _startTrip(); // Llama a la función _startTrip() aquí
    
  }

  

  void _initializeCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;
    _googleMapControllerCompleter.complete(controller);

    String mapStyle = await _getJsonFileFromThemes("themes/night_style.json");
    _setGoogleMapStyle(mapStyle);

    // Centrar la cámara en la ubicación actual del conductor
    _getCurrentLiveLocationOfDriver();
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(), // Utilizar instantiateImageCodec en lugar de instantiateImageCodecFromMemory
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  }

  Future<String> _getJsonFileFromThemes(String mapStylePath) async {
    ByteData byteData = await rootBundle.load(mapStylePath);
    var list = byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return utf8.decode(list);
  }

  void _setGoogleMapStyle(String setGoogleMapStyle) {
    _googleMapController?.setMapStyle(setGoogleMapStyle);
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        double latitude = locations.first.latitude;
        double longitude = locations.first.longitude;
        return LatLng(latitude, longitude);
      }
    } catch (e) {
      print("Error obtaining coordinates: $e");
    }
    return null;
  }

  Future<List<LatLng>> _getRouteCoordinates(LatLng start, LatLng end) async {
    List<LatLng> coordinates = [];
    String apiUrl =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=AIzaSyDzqRjwQQbSKSa24PFoGFhR7HD17LM05R8";
    var response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      List<dynamic> routes = data["routes"];

      if (routes.isNotEmpty) {
        String encodedPoints = routes[0]["overview_polyline"]["points"];
        List<LatLng> decodedPoints = _decodePoly(encodedPoints);
        coordinates.addAll(decodedPoints);
      }
    } else {
      throw Exception('Failed to load route');
    }

    print('Route Coordinates: $coordinates');
    return coordinates;
  }

  List<LatLng> _decodePoly(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng((lat / 1E5), (lng / 1E5)));
    }

    return points;
  }

void _getFletesFromFirebase() async {
  DatabaseReference databaseReference =
      FirebaseDatabase.instance.reference().child('Fletes');

  DatabaseEvent event = await databaseReference.once();
  DataSnapshot dataSnapshot = event.snapshot;

  if (dataSnapshot.value != null) {
    if (dataSnapshot.value is Map) {
      Map<dynamic, dynamic> mapData =
          dataSnapshot.value as Map<dynamic, dynamic>;

      mapData.forEach((key, value) async {
        String startAddress = value['startAddress'];
        LatLng? startCoords = await _getLatLngFromAddress(startAddress);

        if (startCoords != null && value['state'] == 'en espera') {
          // Cargar la imagen personalizada
          Uint8List markerIcon = await _getBytesFromAsset(
            'assets/images/paquete.png', // Ruta de la imagen personalizada
            100, // Ancho deseado de la imagen (puedes ajustarlo según tus necesidades)
          );

          setState(() {
            _markers.add(
              Marker(
                markerId: MarkerId(key.toString()),
                position: startCoords,
                icon: BitmapDescriptor.fromBytes(markerIcon), // Usar la imagen personalizada
                infoWindow: InfoWindow(
                  title: 'Flete Disponible',
                ),
                onTap: () {
                  _showFleteInfoModal(value, key.toString());
                },
              ),
            );
            _allFletes.add(value);
            if (value['state'] == 'aceptado' &&
                value['driverId'] == _currentUser!.uid) {
              _pendingFletes.add(value);
            }
          });
        } else if (value['state'] == 'aceptado' &&
            value['driverId'] == _currentUser!.uid) {
          _pendingFletes.add(value);
        }
      });
    }
  }
}


  late String userEmail = "";
  late String userPhotoUrl = "";
String? _startAddress;
String? _endAddress;
String? _userName;
String? _userSurname;
String? _time;
String? _number;
String? _state;
String? _fleteId; // Declaración de la variable _fleteId
String? _offerRate;

Future<String> _loadDriverImage() async {
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

@override
Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
      const double cardHeight = 250; 

  return Positioned.fill(
    child: Scaffold(
    key: _scaffoldKey, // Asigna la clave global al Scaffold

      // appBar: AppBar(
      //   title: Text("FleT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
      //   automaticallyImplyLeading: false,
      // ),
      drawer: DrawerWidget(), // Aquí incluye tu Drawer

      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(0, 0),
              zoom: 12.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Desactivar el botón de ubicación predeterminado
            rotateGesturesEnabled: true, // Habilita la rotación del mapa mediante gestos
            zoomControlsEnabled: false, // Desactivar los botones de zoom predeterminados
          ),
Visibility(
  visible: _showFletesPendientesButton,
  child: Positioned(
    left: 30, // Posicionar un poco más hacia la derecha
    bottom: 60, // Subir un poco más desde el borde inferior
    child: SizedBox(
      width: 70, // Hacer el botón un poco más grande
      height: 70,
      child: FloatingActionButton(
        onPressed: () {
                  _showPendingFletes(); // Mostrar fletes pendientes al presionar el botón flotante

        }, // Mantener la misma acción o agregar la lógica necesaria
        backgroundColor: Colors.orange,
        child: Icon(Icons.list), // Usar solo el icono sin texto
        shape: CircleBorder(), // Hacer que el botón sea redondo
      ),
    ),
  ),
),


Visibility(
  visible: _showProfileImage,
  child: Positioned(
    left: 20,
    top: 80,
    child: GestureDetector(
      onTap: () {
        try {
          _scaffoldKey.currentState?.openDrawer();
        } catch (e) {
          print('Error al abrir el Drawer: $e');
        }
      },
      child: Container(
        width: 70,
        height: 70,
        padding: EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: Color.fromARGB(255, 255, 255, 255),
            width: 2,
          ),
        ),
        child: FutureBuilder<String>(
          future: _loadDriverImage(), // Llama al método para cargar la imagen del conductor
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // Si la carga de la imagen está completa, muestra la imagen del conductor
              return ClipOval(
                child: Image.network(
                  snapshot.data ?? "", // Utiliza la URL de la imagen del conductor obtenida del futuro
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              // Muestra un indicador de carga mientras se carga la imagen
              return Center(
                child: CircularProgressIndicator(),
              );
            }
          },
        ),
      ),
    ),
  ),
),


 Positioned(
  bottom: _showContinueToDeliveryButton || _showFinishDeliveryButton || _showContinueToDeliveryButton2 ? cardHeight + 20 : 80, // Ajusta este valor según la visibilidad de la card
  right: 20, 
  child: Column(
    children: [
      SizedBox(
        width: 50,
        height: 50,
        child: FloatingActionButton(
          onPressed: _getCurrentLiveLocationOfDriver,
          backgroundColor: Colors.white,
          child: Icon(Icons.gps_fixed, color: Colors.orange),
        ),
      ),
    ],
  ),
),

if (_showStartTripButton)
  Positioned(
    top: 30,
    left: 20,
    right: 20,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: ui.Color.fromARGB(255, 94, 94, 94).withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
            margin: EdgeInsets.only(right: 8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FutureBuilder(
                  future: _getUserDetails(_selectedFleteInfo?['userId'] ?? ""),
                  builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    } else {
                      if (snapshot.hasError) {
                        return Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.white),
                        );
                      } else {
                        Map<String, dynamic>? userDetails = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFleteInfo?['startAddress'] ?? "",
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.start,
                            ),
                            SizedBox(height: 5),
                            Text(
                              "${userDetails?['name']} ${userDetails?['surname']}",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showStartTripButton = false;
              });
              _tripStarted = true;
              _startTrip();
              _showFletesPendientesButton = false;
              
            },
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange,
              ),
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
          if (_showStartTripButton2) 
  Positioned(
    top: 30,
    left: 20,
    right: 20,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: ui.Color.fromARGB(255, 94, 94, 94).withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
            margin: EdgeInsets.only(right: 8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FutureBuilder(
                  future: _getUserDetails(_selectedFleteInfo?['userId'] ?? ""),
                  builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    } else {
                      if (snapshot.hasError) {
                        return Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.white),
                        );
                      } else {
                        Map<String, dynamic>? userDetails = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFleteInfo?['endAddress'] ?? "",
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.start,
                            ),
                            SizedBox(height: 5),
                            Text(
                              "${userDetails?['name']} ${userDetails?['surname']}",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
  _showFinishDeliveryButton = true;
  _showContinueToDeliveryButton2= false;
                              _showStartTripButton2 = false;
              });
              _startTrip3();
              _showFletesPendientesButton = false;
              _tripStarted = true;
            },
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange,
              ),
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  ),




  if (_showFinishDeliveryButton) 
 Positioned(
    bottom: 20,
    left: 20,
    right: 20,
    child: Card(
      color: Colors.black87, // Color oscuro al estilo Uber
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Rumbo al Destino de entrega",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Dirigete a(l) $_endAddress", // Asume que $_time es una variable ya definida
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage('assets/images/perfil.png'),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "$_userName", // Supone que _userName es una variable ya definida
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    String phoneNumber = '$_number'; // Asigna aquí el número de teléfono del usuario
                    _launchPhoneCall(phoneNumber);
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.phone, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
           GestureDetector(
  onTap: () async {
    try {
      // Construye la URL para actualizar el estado del flete
      String apiUrl = 'https://webapi-fletmin2.onrender.com/api/fletes/$_fleteId';
      
      // Crea un mapa con el nuevo estado del flete
      Map<String, dynamic> requestBody = {
        'state': 'En Destino',
      };

      // Realiza la solicitud PUT a la API para actualizar el estado dAel flete
      var response = await http.put(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      // Verifica si la solicitud fue exitosa
      if (response.statusCode == 200) {
        // Si la solicitud fue exitosa, actualiza el estado local
        setState(() {
          _state = 'En Destino';
         _showStartTripButton2 = false;
        _showTripStatusCard(context);
        });
        
        // Muestra un mensaje de éxito
             ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Espera a recoger el paquete y continua".'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 7), // Establece la duración del SnackBar en 7 segundos
        ),
      );

      } else {
        // Si la solicitud no fue exitosa, muestra un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el estado del flete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      // Maneja cualquier error que ocurra durante la solicitud
      print('Error: $error');
    }
  },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "Llegue a la entrega",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  

if (_showContinueToDeliveryButton)
  Positioned(
    bottom: 20,
    left: 20,
    right: 20,
    child: Card(
      color: Colors.black87, // Color oscuro al estilo Uber
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Rumbo al punto de encuentro",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Llega antes de la(s) $_time", // Asume que $_time es una variable ya definida
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 16),
            //    Text(
            //   "Vas $_state", // Asume que $_time es una variable ya definida
            //   style: TextStyle(color: Colors.white70, fontSize: 16),
            // ),
            // SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage('assets/images/perfil.png'),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "$_userName", // Supone que _userName es una variable ya definida
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    String phoneNumber = '$_number'; // Asigna aquí el número de teléfono del usuario
                    _launchPhoneCall(phoneNumber);
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.phone, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
  GestureDetector(
  onTap: () async {
    try {
      // Construye la URL para actualizar el estado del flete
      String apiUrl = 'https://webapi-fletmin2.onrender.com/api/fletes/$_fleteId';
      
      // Crea un mapa con el nuevo estado del flete
      Map<String, dynamic> requestBody = {
        'state': 'Recogiendo',
      };

      // Realiza la solicitud PUT a la API para actualizar el estado dAel flete
      var response = await http.put(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      // Verifica si la solicitud fue exitosa
      if (response.statusCode == 200) {
        // Si la solicitud fue exitosa, actualiza el estado local
        setState(() {
          _state = 'Recogiendo';
          _showContinueToDeliveryButton2 = true;
          _showContinueToDeliveryButton = false;
        });
        
        // Muestra un mensaje de éxito
             ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Espera a recoger el paquete y continua".'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 7), // Establece la duración del SnackBar en 7 segundos
        ),
      );

      } else {
        // Si la solicitud no fue exitosa, muestra un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el estado del flete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      // Maneja cualquier error que ocurra durante la solicitud
      print('Error: $error');
    }
  },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "Llegué por el Pedido",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  
  if (_showContinueToDeliveryButton2)
  Positioned(
    bottom: 20,
    left: 20,
    right: 20,
    child: Card(
      color: Colors.black87, // Color oscuro al estilo Uber
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Recogiendo paquete",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Continua al punto de Destino cuando tengas el paquete", // Asume que $_time es una variable ya definida
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage('assets/images/perfil.png'),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "$_userName", // Supone que _userName es una variable ya definida
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    String phoneNumber = '$_number'; // Asigna aquí el número de teléfono del usuario
                    _launchPhoneCall(phoneNumber);
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.phone, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
    try {
      // Construye la URL para actualizar el estado del flete
      String apiUrl = 'https://webapi-fletmin2.onrender.com/api/fletes/$_fleteId';
      
      // Crea un mapa con el nuevo estado del flete
      Map<String, dynamic> requestBody = {
        'state': 'Al destino',
      };

      // Realiza la solicitud PUT a la API para actualizar el estado del flete
      var response = await http.put(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      // Verifica si la solicitud fue exitosa
      if (response.statusCode == 200) {
        // Si la solicitud fue exitosa, actualiza el estado local
        setState(() {
          _state = 'Al Destino';
           _tripStarted = false;
                _startTrip2();
                _showFletesPendientesButton = false;
                _showContinueToDeliveryButton = false; // Ocultar la tarjeta después de la acción
                _showContinueToDeliveryButton2 = false;
        });
        
        // Muestra un mensaje de éxito
             ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viaje comenzado al punto de destino.'),
          backgroundColor: Colors.green,
        ),
      );

      } else {
        // Si la solicitud no fue exitosa, muestra un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el estado del flete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      // Maneja cualquier error que ocurra durante la solicitud
      print('Error: $error');
    }
  },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "Continuar",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  )
  


        ],
      ),
    ),
  );
}






 void _showPendingFletes() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromARGB(255, 255, 255, 255), // Establecer el color de fondo blanco
          title: Text(
            "Fletes Pendientes",
            style: TextStyle(color: Colors.black), // Texto en negro
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _pendingFletes.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildFleteCard(_pendingFletes[index]);
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.orange, // Fondo naranja
                onPrimary: Colors.white, // Texto en blanco
              ),
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFleteCard(Map<dynamic, dynamic> fleteInfo) {
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        title: Text(fleteInfo['date'] ?? ""),
        subtitle: Text("Hora: ${fleteInfo['time']}, Tarifa: ${fleteInfo['offerRate']}"),
        onTap: () {
          // Acción al presionar el flete pendiente
          Navigator.of(context).pop(); // Cerrar el diálogo de fletes pendientes
          _showFleteDetailsModal(fleteInfo); // Mostrar detalles del flete
        },
      ),
    );
  }

  void _showFleteDetailsModal(Map<dynamic, dynamic> fleteInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Aquí estableces el color de fondo
          title: Text(
            "Detalles del Flete",
            style: TextStyle(color: Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Descripción', fleteInfo['description'] ?? ""),
                _buildInfoRow('Fecha', fleteInfo['date'] ?? ""),
                _buildInfoRow('Dirección de inicio', fleteInfo['startAddress'] ?? ""),
                _buildInfoRow('Dirección de entrega', fleteInfo['endAddress'] ?? ""),
                _buildInfoRow('Hora', fleteInfo['time'] ?? ""),
                _buildInfoRow('Tipo de vehículo', fleteInfo['vehicleType'] ?? ""),
                _buildInfoRow('Pago', fleteInfo['offerRate'] ?? ""),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo de detalles del flete
                _showPendingFletes(); // Mostrar la lista de fletes pendientes nuevamente
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.orange,
                onPrimary: Colors.white,
              ),
              child: Text("Regresar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo de detalles del flete
                showModalBottomSheet(
                  context: context,
                  builder: (BuildContext context) {
                    return _buildSecondModal();
                  },
                );
              },
                
              style: ElevatedButton.styleFrom(
                primary: Colors.orange,
                onPrimary: Colors.white,
              ),
              child: Text("Continuar"),
            ),
          ],
        );
      },
    );
  }

Widget _buildSecondModal() {
  return Container(
    width: MediaQuery.of(context).size.width * 0.9,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 20),
        Row(
          children: [
            _buildProgressBarSegment(Colors.green, 0.30),
            _buildProgressBarSegment(Color.fromARGB(255, 229, 229, 229), 0.05),
            _buildProgressBarSegment(Colors.green, 0.15),
            _buildProgressBarSegment(Color.fromARGB(255, 223, 223, 223), 0.05),
            _buildProgressBarSegment(Colors.green, 0.25),
          ],
        ),
        SizedBox(height: 20),
        Image.asset(
          'assets/images/reparti.png',
          width: 100,
          height: 100,
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            primary: Colors.transparent,
            elevation: 0,
          ),
          child: Ink(
            child: InkWell(
              onTap: () {
              },
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.amber],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: Text(
                    'Comenzar recorrido',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(); // Cerrar el diálogo de detalles del flete
            _showPendingFletes(); // Mostrar la lista de fletes pendientes nuevamente
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            primary: Colors.transparent,
            elevation: 0,
          ),
          child: Ink(
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop(); // Cerrar el diálogo de detalles del flete
                _showPendingFletes(); // Mostrar la lista de fletes pendientes nuevamente
              },
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.amber],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: Text(
                    'Regresar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    ),
  );
}









_launchPhoneCall(String phoneNumber) async {
  String url = 'tel:$phoneNumber';
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'No se pudo iniciar la llamada: $url';
  }
}

void _showTripStatusCard(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.3, // Abre la ventana en menos de la mitad pero se muestra completa
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10.0),
              topRight: Radius.circular(10.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.0),
              Container(
                alignment: Alignment.center,
                child: Text(
                  'Flete en curso...',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 20.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5.0),
                          Text(
                            'Pago en tarjeta',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.0),
            GestureDetector(
  onTap: () async {
    try {
      // Construye la URL para actualizar el estado del flete
      String apiUrl = 'https://webapi-fletmin2.onrender.com/api/fletes/$_fleteId';
      
      // Crea un mapa con el nuevo estado del flete
      Map<String, dynamic> requestBody = {
        'state': 'Finalizado',
      };

      // Realiza la solicitud PUT a la API para actualizar el estado del flete
      var response = await http.put(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      // Verifica si la solicitud fue exitosa
      if (response.statusCode == 200) {
        // Si la solicitud fue exitosa, actualiza el estado local
        setState(() {
          _state = 'Finalizado';
          _showContinueToDeliveryButton2 = false; // Oculta el botón de continuar
        });
        
        // Muestra un mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flete finalizado exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
double offerRate = double.tryParse(_offerRate ?? '') ?? 0;

        // Navega a la página DetallePagoPage
       Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => DetallePagoPage(offerRate: offerRate),
    ),
  );

      } else {
        // Si la solicitud no fue exitosa, muestra un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar el flete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      // Maneja cualquier error que ocurra durante la solicitud
      print('Error: $error');
    }
  },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      padding: EdgeInsets.all(10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 30.0,
                          ),
                          SizedBox(width: 10.0),
                          Text(
                            'Finalizar Flete',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.0),
            ],
          ),
        ),
      );
    },
  );
} 

  void _acceptFlete2(Map<dynamic, dynamic> fleteInfo, String fleteId) {
    DatabaseReference databaseReference =
        FirebaseDatabase.instance.reference().child('Fletes');

    String driverId = _currentUser!.uid;

    databaseReference.child(fleteId).update({
      'state': 'Recogiendo',
    }).then((_) {
      print('Flete Recogido con éxito');
    }).catchError((error) {
      print('Error al Recoger el flete: $error');
    });
  }





  



void _getCurrentLiveLocationOfDriver() async {
    Position positionOfDriver = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation);

  LatLng driverPosition = LatLng(positionOfDriver.latitude, positionOfDriver.longitude);
  
  _driverLocationStreamController.add(driverPosition);
  
  Position positionOfUser = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation);
  _currentPositionOfUser = positionOfUser;

  LatLng positionOfUserInLatLng = LatLng(
      _currentPositionOfUser!.latitude, _currentPositionOfUser!.longitude);

  CameraPosition cameraPosition = CameraPosition(
    target: positionOfUserInLatLng,
    zoom: 15,
    tilt: 0,
    bearing: _currentPositionOfUser!.heading ?? 0, // Utiliza la orientación del conductor para la orientación del mapa
  );

  // Mover la cámara a la posición actual del conductor
  _googleMapController?.moveCamera(CameraUpdate.newCameraPosition(cameraPosition));

  // Actualizar la última posición de la cámara
  _lastCameraPosition = positionOfUserInLatLng;
}


void _showFleteInfoModal(Map<dynamic, dynamic> fleteInfo, String fleteId) async {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return FutureBuilder(
        future: _getUserDetails(fleteInfo['userId']),
        builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            } else {
              Map<String, dynamic>? userDetails = snapshot.data;
              return ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [const ui.Color.fromARGB(255, 255, 123, 0), Colors.yellow],
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Flete disponible',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 10),
                                ListTile(
                                  leading: userDetails?['photo'] != null
                                      ? CircleAvatar(
                                          radius: 30,
                                          backgroundImage: NetworkImage(userDetails?['photo']),
                                        )
                                      : Icon(Icons.account_circle, size: 60, color: Colors.orange),
                                  title: Text(
                                    '${userDetails?['name']} ${userDetails?['surname']}' ?? "",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(userDetails?['number'] ?? "", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detalles del Flete',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 10),
                              ..._buildFleteDetails(fleteInfo, fleteId), // Función para construir los detalles del flete
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                            _acceptFlete(fleteInfo, fleteId); // Acepta el flete
                                Navigator.of(context).pop();
                                setState(() {
                                  _showTriangularWindow = true;
                                  _selectedFleteInfo = fleteInfo;
                                  _startAddress = fleteInfo['startAddress'];
                                  _endAddress = fleteInfo['endAddress'];
                                  _state = fleteInfo['state'];
                                  _time = fleteInfo['time'];
                                  _userName = userDetails?['name'];
                                  _userSurname = userDetails?['surname'];
                                  _number = userDetails?['number'];
                                  _fleteId = fleteId;
                                  _offerRate = fleteInfo['offerRate'];
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                primary: Colors.orange,
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: Text(
                                'Aceptar Flete',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                primary: Colors.orange,
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: Text(
                                'Rechazar Flete',
                                style: TextStyle(color: const ui.Color.fromARGB(255, 255, 255, 255), fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            }
          }
        },
      );
    },
  );
}

List<Widget> _buildFleteDetails(Map<dynamic, dynamic> fleteInfo, String fleteId) {
  return [

    ListTile(
      leading: Icon(Icons.description, color: Colors.orange),
      title: Text('Descripción:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['description'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
    ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.orange),
      title: Text('Fecha:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['date'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
    ListTile(
      leading: Icon(Icons.location_on, color: Colors.orange),
      title: Text('Dirección de inicio:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['startAddress'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
    ListTile(
      leading: Icon(Icons.location_on, color: Colors.orange),
      title: Text('Dirección de entrega:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['endAddress'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
    ListTile(
      leading: Icon(Icons.access_time, color: Colors.orange),
      title: Text('Hora:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['time'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
    ListTile(
      leading: Icon(Icons.local_shipping, color: Colors.orange),
      title: Text('Tipo de vehículo:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['vehicleType'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
    ListTile(
      leading: Icon(Icons.attach_money, color: Colors.orange),
      title: Text('Pago:', style: TextStyle(color: Colors.black)),
      subtitle: Text(fleteInfo['offerRate'] ?? "", style: TextStyle(color: Colors.grey)),
    ),
  ];
}

Future<Map<String, dynamic>> _getUserDetails(String userId) async {
  DatabaseReference databaseReference = FirebaseDatabase.instance.reference().child('Users').child(userId);
  DataSnapshot dataSnapshot = (await databaseReference.once()).snapshot;
  Map<dynamic, dynamic> userData = dataSnapshot.value as Map<dynamic, dynamic>;
  return {
    'name': userData['name'],
    'surname': userData['surname'],
    'number': userData['number'],
    'photo': userData['photo'], // Agregar la URL de la foto del usuario
  };
}


  void _acceptFletes(Map<dynamic, dynamic> fleteInfo, String fleteId) {
    DatabaseReference databaseReference =
        FirebaseDatabase.instance.reference().child('Fletes');

    String driverId = _currentUser!.uid;

    databaseReference.child(fleteId).update({
      'state': 'aceptado pendientes',
    }).then((_) {
      setState(() {
        _pendingFletes.add(fleteInfo); // Agrega todo el flete a la lista pendiente
      });
      print('Flete aceptado con éxito');
    }).catchError((error) {
      print('Error al aceptar el flete: $error');
    });
  }

 


  void _acceptFlete(Map<dynamic, dynamic> fleteInfo, String fleteId) {
    DatabaseReference databaseReference =
        FirebaseDatabase.instance.reference().child('Fletes');

    String driverId = _currentUser!.uid;

    databaseReference.child(fleteId).update({
      'state': 'aceptado',
      'driverId': driverId,
    }).then((_) {
      print('Flete aceptado con éxito');
      _buildTriangularWindow(fleteInfo, fleteId);
    }).catchError((error) {
      print('Error al aceptar el flete: $error');
    });
  }
  
void _updateFlete(Map<dynamic, dynamic> fleteInfo, String fleteId) async {
  DatabaseReference databaseReference =
      FirebaseDatabase.instance.reference().child('Fletes');

  // Cambiar el estado del flete a "En camino"
  await databaseReference.child(fleteId).update({
    'state': 'En camino',
  });

  // Iniciar la escucha de la ubicación del conductor y guardarla en la base de datos
  _startLocationUpdatesForFlete(fleteId);

 
  print('Flete en camino');
}

void _startLocationUpdatesForFlete(String fleteId) {
  Geolocator.getPositionStream().listen((Position position) async {
    LatLng driverPosition = LatLng(position.latitude, position.longitude);

    // Actualizar la ubicación del flete en la base de datos
    DatabaseReference databaseReference = FirebaseDatabase.instance.reference();
    String driverId = _currentUser!.uid;
    await databaseReference.child('Fletes/$fleteId/Location').set({
      'latitude': driverPosition.latitude,
      'longitude': driverPosition.longitude,
    });
  });
}



  void _buildTriangularWindow(Map<dynamic, dynamic> fleteInfo, String fleteId) {
    showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
      backgroundColor: Colors.white,
    isScrollControlled: true, // Permitir scroll dentro del BottomSheet
    builder: (BuildContext context) {
      return SingleChildScrollView( // Envuelve el contenido con SingleChildScrollView
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8), // Establece una altura máxima
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressBarSegment(Colors.green, 0.30),
                  _buildProgressBarSegment(Color.fromARGB(255, 234, 234, 234), 0.05),
                  _buildProgressBarSegment(Colors.green, 0.15),
                  _buildProgressBarSegment(Color.fromARGB(255, 234, 234, 234), 0.05),
                  _buildProgressBarSegment(Colors.green, 0.25),
                ],
              ),
              SizedBox(height: 20),
              Image.asset(
                'assets/images/reparti.png',
                width: 100,
                height: 100,
              ),
              SizedBox(height: 20),
              Text(
                'Comienza tu viaje 📍',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Fecha: ${fleteInfo['date']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Oferta: ${fleteInfo['offerRate']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _acceptFletes(fleteInfo, fleteId); 
                  Navigator.of(context).pop();
                  setState(() {
                    _showTriangularWindow = true;
                    _selectedFleteInfo = fleteInfo;
                    _fleteId = fleteId;
                  });
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.orange,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Ink(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.amber],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Agregar a Fletes Pendientes',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10), // Espacio adicional entre botones
   ElevatedButton(
  onPressed: () {
    if (_currentPositionOfUser != null) {
      _showRouteOnMap(fleteInfo); // Llama a la función para mostrar la ruta en el mapa
      Navigator.of(context).pop(); // Cerrar la ventana modal
      setState(() {
        _updateFlete(fleteInfo, fleteId); // Solo pasamos los dos argumentos requeridos
        _showFletesPendientesButton = false;
        _showProfileImage = false; // Esconde el círculo de la imagen
        // Ocultar el Dashboard
      });
    } else {
      // Manejo de casos en los que la ubicación del conductor no está disponible
      print('Error: Ubicación del conductor no disponible');
    }
  },
  style: ElevatedButton.styleFrom(
    primary: Colors.orange,
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),


  child: Ink(
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.amber],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          ' Recorrido',
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  ),
),

              SizedBox(height: 20),
            ],
          ),
       ),
     );
      },
    );
  }

void _showRouteOnMap(Map<dynamic, dynamic> fleteInfo) async {
  // Obtener la dirección de inicio del flete
  String startAddress = fleteInfo['startAddress'];
  LatLng? startCoords = await _getLatLngFromAddress(startAddress);

  if (startCoords != null) {
    // Obtener la posición actual del conductor
    LatLng currentPosition = LatLng(
        _currentPositionOfUser!.latitude, _currentPositionOfUser!.longitude);

    // Eliminar el marcador de la ubicación actual
    _markers.removeWhere((marker) => marker.markerId.value == 'currentPosition');

    // Obtener la ruta desde la ubicación actual hasta la dirección de inicio del flete
    List<LatLng> routeCoordinates =
        await _getRouteCoordinates(currentPosition, startCoords);

    // Obtener la imagen de los assets como bytes
    Uint8List markerIcon = await _getBytesFromAsset(
      'assets/images/paquete.png', // Ruta de la imagen en los assets
      100, // Ancho deseado de la imagen (puedes ajustarlo según tus necesidades)
    );
// Ocultar el Dashboard
      _showDashboard = false;

      // Print para verificar el cambio en la visibilidad del Dashboard
      print("_showDashboard: $_showDashboard");


      
    setState(() {
      // Limpiar los marcadores existentes
      _markers.clear();
      // Agregar marcador para la dirección de inicio del flete con la imagen personalizada
      _markers.add(
        Marker(
          markerId: MarkerId('startAddress'),
          position: startCoords,
          icon: BitmapDescriptor.fromBytes(markerIcon),
        ),
      );
      // Dibujar la ruta en el mapa
      _drawRoute(routeCoordinates);

      // Anima la cámara del mapa para que se centre en la posición actual del conductor
      _googleMapController?.animateCamera(CameraUpdate.newLatLng(currentPosition));
   _showStartTripButton = true;
      // Mostrar el botón "Comenzar viaje" después de configurar la ruta y la cámara
     

    });
  }
}


  void _drawRoute(List<LatLng> routeCoordinates) {
    Polyline polyline = Polyline(
      polylineId: PolylineId('route'),
      color: Colors.orange,
      points: routeCoordinates,
      width: 5,
    );

    setState(() {
      _polylines.add(polyline);
    });
  }


void _startTrip() async {
  try {
    // Obtener la posición actual del usuario una vez
    Position position = await Geolocator.getCurrentPosition();

    // Convertir la posición a LatLng
    LatLng currentPosition = LatLng(position.latitude, position.longitude);

    // Mover la cámara del mapa de forma instantánea a la posición actual con la orientación del conductor
    _googleMapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentPosition,
          zoom: 17,
          tilt: 45,
          bearing: position.heading ?? 0,
        ),
      ),
    );

    // Actualizar la última posición de la cámara
    _lastCameraPosition = currentPosition;

    // Obtener el ID del flete seleccionado
    String? selectedFleteId = _selectedFleteInfo?['fleteId'];

    if (selectedFleteId != null) {
      try {
        // Actualizar el estado del flete a 'Llendo a recoger' en Firebase
        DatabaseReference fletesReference = FirebaseDatabase.instance.reference().child('Fletes');
        fletesReference.child(selectedFleteId).update({'state': 'Llendo a recoger'});
        print('Estado del flete actualizado a "Llendo a recoger"');
      } catch (e) {
        // Manejar cualquier error que ocurra al actualizar el estado del flete
        print('Error al actualizar el estado del flete: $e');
      }
    }

    // Suscribirse a las actualizaciones de posición del conductor
    _positionStream = Geolocator.getPositionStream().listen((Position newPosition) {
      // Convertir la nueva posición a LatLng
      LatLng newPositionLatLng = LatLng(newPosition.latitude, newPosition.longitude);

      // Si el viaje ha comenzado, mover la cámara del mapa para que se centre en la nueva posición del usuario
      if (_tripStarted) {
        // Aplicar una interpolación suave para la transición de la cámara
        _googleMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPositionLatLng,
              zoom: 17, // Opcional: puedes ajustar el nivel de zoom aquí
              tilt: 45,
              bearing: newPosition.heading ?? 0,
            ),
          ),
        );

        _lastCameraPosition = newPositionLatLng;
          setState(() {
      _showContinueToDeliveryButton = true;
      
    });
      }
    });   
  } catch (e) {
    // Manejar cualquier error que ocurra al obtener la posición del usuario
    print('Error al obtener la posición del usuario: $e');
  }
}




void _startTrip3() async {
  try {
    // Obtener la posición actual del usuario una vez
    Position position = await Geolocator.getCurrentPosition();

    // Convertir la posición a LatLng
    LatLng currentPosition = LatLng(position.latitude, position.longitude);

    // Mover la cámara del mapa de forma instantánea a la posición actual con la orientación del conductor
    _googleMapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentPosition,
          zoom: 17,
          tilt: 45,
          bearing: position.heading ?? 0,
        ),
      ),
    );

    // Actualizar la última posición de la cámara
    _lastCameraPosition = currentPosition;

    // Obtener el ID del flete seleccionado
    String? selectedFleteId = _selectedFleteInfo?['fleteId'];

    if (selectedFleteId != null) {
      try {
        // Actualizar el estado del flete a 'Llendo a recoger' en Firebase
        DatabaseReference fletesReference = FirebaseDatabase.instance.reference().child('Fletes');
        fletesReference.child(selectedFleteId).update({'state': 'Llendo a recoger'});
        print('Estado del flete actualizado a "Llendo a recoger"');
      } catch (e) {
        // Manejar cualquier error que ocurra al actualizar el estado del flete
        print('Error al actualizar el estado del flete: $e');
      }
    }

    // Suscribirse a las actualizaciones de posición del conductor
    _positionStream = Geolocator.getPositionStream().listen((Position newPosition) {
      // Convertir la nueva posición a LatLng
      LatLng newPositionLatLng = LatLng(newPosition.latitude, newPosition.longitude);

      // Si el viaje ha comenzado, mover la cámara del mapa para que se centre en la nueva posición del usuario
      if (_tripStarted) {
        // Aplicar una interpolación suave para la transición de la cámara
        _googleMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPositionLatLng,
              zoom: 17, // Opcional: puedes ajustar el nivel de zoom aquí
              tilt: 45,
              bearing: newPosition.heading ?? 0,
            ),
          ),
        );

        _lastCameraPosition = newPositionLatLng;
          setState(() {
      _showContinueToDeliveryButton = false;
                        _showStartTripButton2 = false;

      
    });
      }
    });   
  } catch (e) {
    // Manejar cualquier error que ocurra al obtener la posición del usuario
    print('Error al obtener la posición del usuario: $e');
  }
}




  Widget _buildProgressBarSegment(Color color, double widthPercentage) {
    return Expanded(
      child: Container(
        height: 4, // Ajusta la altura según tus necesidades
        color: color,
        width: MediaQuery.of(context).size.width * widthPercentage,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }










void _showRouteOnMap2(Map<dynamic, dynamic> fleteInfo) async {
  // Obtener la dirección de inicio del flete
  String endAddress = fleteInfo['endAddress'];
  LatLng? startCoords = await _getLatLngFromAddress(endAddress);

  if (startCoords != null) {
    // Obtener la ruta desde la ubicación actual hasta la dirección de inicio del flete
    List<LatLng> routeCoordinates = await _getRouteCoordinates(
      LatLng(_currentPositionOfUser!.latitude, _currentPositionOfUser!.longitude),
      startCoords,
    );

    // Obtener la cámara que abarca todo el recorrido
    LatLngBounds bounds = _getBoundsForCoordinates(routeCoordinates);

    // Mover la cámara del mapa para que abarque todo el recorrido
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100), // 100 es el padding en píxeles alrededor de los límites
    );

    // Obtener la imagen de los assets como bytes
    Uint8List markerIcon = await _getBytesFromAsset(
      'assets/images/paquete.png', // Ruta de la imagen en los assets
      100, // Ancho deseado de la imagen (puedes ajustarlo según tus necesidades)
    );

    setState(() {  
      _showContinueToDeliveryButton = false;
                  _showStartTripButton2 = true;
      // Limpiar los marcadores existentes
      _markers.clear();
      // Agregar marcador para la dirección de inicio del flete con la imagen personalizada
      _markers.add(
        Marker(
          markerId: MarkerId('endAddress'),
          position: startCoords,
          icon: BitmapDescriptor.fromBytes(markerIcon),
          
        ),
      );
      // Dibujar la ruta en el mapa
      _drawRoute(routeCoordinates);

      // Mostrar el botón "Comenzar viaje" después de configurar la ruta y la cámara
});
  }
} 
LatLngBounds _getBoundsForCoordinates(List<LatLng> coordinates) {
  double minLat = double.infinity;
  double minLng = double.infinity;
  double maxLat = -double.infinity;
  double maxLng = -double.infinity;

  for (LatLng coordinate in coordinates) {
    if (coordinate.latitude < minLat) minLat = coordinate.latitude;
    if (coordinate.latitude > maxLat) maxLat = coordinate.latitude;
    if (coordinate.longitude < minLng) minLng = coordinate.longitude;
    if (coordinate.longitude > maxLng) maxLng = coordinate.longitude;
  }

  LatLng southwest = LatLng(minLat, minLng);
  LatLng northeast = LatLng(maxLat, maxLng);

  return LatLngBounds(southwest: southwest, northeast: northeast);
}


void _startTrip2() async {
  _showRouteOnMap2(_selectedFleteInfo!);
  
  setState(() {
    _showContinueToDeliveryButton = false;
            _showStartTripButton = false;

  });
}


}
