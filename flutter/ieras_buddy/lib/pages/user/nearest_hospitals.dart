import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NearestHospitalPage extends StatefulWidget {
  const NearestHospitalPage({super.key});

  @override
  State<NearestHospitalPage> createState() => _NearestHospitalPageState();
}

class _NearestHospitalPageState extends State<NearestHospitalPage> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(11.258753, 75.780411); // Default Kozhikode location
  Set<Marker> _markers = {};
  BitmapDescriptor? _hospitalIcon;
  double _currentZoom = 16;
  List<Map<String, dynamic>> _places = []; // Stores dynamically fetched hospital data

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _trackUserLocation();
  }

  // Load hospital icon from assets
  Future<void> _loadCustomIcons() async {
    final Uint8List iconBytes = await _resizeImage('assets/hospital.png', 100);
    setState(() {
      _hospitalIcon = BitmapDescriptor.fromBytes(iconBytes);
    });
  }

  // Resize image for custom markers
  Future<Uint8List> _resizeImage(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Function to fetch hospitals dynamically using OpenStreetMap Overpass API
  Future<void> _fetchHospitals() async {
    final double lat = _currentLocation.latitude;
    final double lng = _currentLocation.longitude;

    final String overpassUrl =
        "https://overpass-api.de/api/interpreter?data=[out:json];"
        "node[amenity=hospital](around:10000,$lat,$lng);out;";

    try {
      final response = await http.get(Uri.parse(overpassUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> hospitals = [];

        for (var element in data["elements"]) {
          hospitals.add({
            "name": element["tags"]["name"] ?? "Unnamed Hospital",
            "lat": element["lat"],
            "lng": element["lon"],
            "phone": element["tags"]["phone"] ?? "", // Some hospitals may have a phone number
          });
        }

        setState(() {
          _places = hospitals;
          _updateMarkers();
        });
      }
    } catch (e) {
      print("Error fetching hospital data: $e");
    }
  }

  // Function to track user location and center the camera on startup
  Future<void> _trackUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDisabledDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = newLocation;
      });

      // Fetch hospitals whenever user location updates
      _fetchHospitals();

      // Move camera to user's location on startup
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(newLocation, _currentZoom));
      }
    });
  }

  // Function to update markers (user + dynamically fetched hospitals)
  void _updateMarkers() {
    _markers.clear();

    // Add hospital markers
    for (var place in _places) {
      _markers.add(
        Marker(
          markerId: MarkerId(place["name"]),
          position: LatLng(place["lat"], place["lng"]),
          infoWindow: InfoWindow(
            title: place["name"],

          ),
          icon: _hospitalIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {}); // Refresh the map
  }


  // Function to show a dialog if location services are disabled
  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Services Disabled"),
        content: const Text("Please enable location services for tracking."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }


  // Apply custom map styling
  Future<void> _applyMapStyle() async {
    String style = await rootBundle.loadString('assets/map_style.json');
    _mapController?.setMapStyle(style);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearest Hospitals',
          style: TextStyle(
            color: Colors
                .redAccent.shade200, // Change title color to a redAccent shade
            fontSize: 24, // Adjust the font size to make it more prominent
            fontWeight: FontWeight.bold, // Use bold font weight
            fontFamily:
            'Roboto', // Optional: Set a custom font family (ensure the font is added to pubspec.yaml)
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 4,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: _currentZoom,
            ),
            markers: _markers,
            mapType: MapType.normal,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _applyMapStyle();
              _fetchHospitals();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,

          ),
        ],
      ),
    );
  }

}

