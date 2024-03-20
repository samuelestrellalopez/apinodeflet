import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:driversapp2/pages/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

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
  LatLng? _lastCameraPosition;
  Map<dynamic, dynamic>? _selectedFleteInfo;
  StreamSubscription<Position>? _positionStream; // Declarar la variable miembro
bool _tripStarted = false; // Variable para controlar si el viaje ha comenzado
bool _showFletesPendientesButton = true;


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
            setState(() {
              _markers.add(
                Marker(
                  markerId: MarkerId(key.toString()),
                  position: startCoords,
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

  @override
  void dispose() {
    super.dispose();
    _positionStream?.cancel();
  }
  
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "FleT",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
          ),
        ),
      ),
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
            myLocationButtonEnabled: true,
          ),
         Visibility(
  visible: _showFletesPendientesButton,
  child: Positioned(
    left: 20,
    top: 20,
    child: FloatingActionButton.extended(
      onPressed: () {},
      label: Text(
        'Fletes Pendientes',
        style: TextStyle(color: Colors.white),
      ),
      icon: Icon(Icons.list),
      backgroundColor: Colors.orange,
    ),
  ),
),

          if (_showStartTripButton) 
            Positioned(
              bottom: 20,
              left: 20,
              child: ElevatedButton(
                onPressed: () {
                  
                      _tripStarted = true;  

                  _startTrip();
                  _showFletesPendientesButton = false;

                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.orange,
                ),
                child: Text(
                  'Comenzar viaje',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _getCurrentLiveLocationOfDriver() async {
    Position positionOfUser = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    _currentPositionOfUser = positionOfUser;

    LatLng positionOfUserInLatLng = LatLng(
        _currentPositionOfUser!.latitude, _currentPositionOfUser!.longitude);

    CameraPosition cameraPosition = CameraPosition(
      target: positionOfUserInLatLng,
      zoom: 15,
      tilt: 0,
      bearing: _currentPositionOfUser!.heading ?? 0,
    );

    // Mover la cámara a la posición actual del conductor
    _googleMapController?.animateCamera(
        CameraUpdate.newCameraPosition(cameraPosition));

    // Actualizar la última posición de la cámara
    _lastCameraPosition = positionOfUserInLatLng;
  }

  void _showFleteInfoModal(Map<dynamic, dynamic> fleteInfo, String fleteId) async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                SizedBox(height: 20),
                _buildInfoRow('Descripción', fleteInfo['description'] ?? ""),
                _buildInfoRow('Fecha', fleteInfo['date'] ?? ""),
                _buildInfoRow('Dirección de inicio', fleteInfo['startAddress'] ?? ""),
                _buildInfoRow('Dirección de entrega', fleteInfo['endAddress'] ?? ""),
                _buildInfoRow('Hora', fleteInfo['time'] ?? ""),
                _buildInfoRow('Tipo de vehículo', fleteInfo['vehicleType'] ?? ""),
                _buildInfoRow('Pago', fleteInfo['offerRate'] ?? ""),
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
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.orange,
                      ),
                      child: Text(
                        'Aceptar Flete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.orange,
                      ),
                      child: Text(
                        'Rechazar Flete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
      setState(() {
        _pendingFletes.add(fleteInfo); // Agrega todo el flete a la lista pendiente
      });
      print('Flete aceptado con éxito');
      _buildTriangularWindow(fleteInfo, fleteId);
    }).catchError((error) {
      print('Error al aceptar el flete: $error');
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
                  _showRouteOnMap(fleteInfo); // Llama a la función para mostrar la ruta en el mapa
                  Navigator.of(context).pop(); // Cerrar la ventana modal
                  
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
                        'Comenzar Recorrido',
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

      // Mostrar el botón "Comenzar viaje" después de configurar la ruta y la cámara
      setState(() {
        _showStartTripButton = true;
      });
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
    // Actualizar el estado para ocultar el botón "Comenzar viaje"
    setState(() {
      _showStartTripButton = false;
    });

    // Obtener la posición actual del usuario una vez
    Position position = await Geolocator.getCurrentPosition();

    // Convertir la posición a LatLng
    LatLng currentPosition = LatLng(position.latitude, position.longitude);

    // Animar la cámara del mapa para que se centre en la posición actual del usuario y gire en consecuencia
    _googleMapController?.animateCamera(
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

    // Suscribirse a las actualizaciones de posición del conductor
    _positionStream = Geolocator.getPositionStream().listen((Position newPosition) {
      // Convertir la nueva posición a LatLng
      LatLng newPositionLatLng = LatLng(newPosition.latitude, newPosition.longitude);

      // Si el viaje ha comenzado, mover la cámara del mapa para que se centre en la nueva posición del usuario
      if (_tripStarted) {
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

        // Actualizar la última posición de la cámara
        _lastCameraPosition = newPositionLatLng;
      }
    });
  } catch (e) {
    // Manejar cualquier error que ocurra al obtener la posición del usuario
    print('Error al obtener la posición del usuario: $e');
  }
}






  Widget _buildProgressBarSegment(Color color, double widthPercentage) {
    return Container(
      width: MediaQuery.of(context).size.width * widthPercentage,
      height: 10,
      color: color,
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
}
