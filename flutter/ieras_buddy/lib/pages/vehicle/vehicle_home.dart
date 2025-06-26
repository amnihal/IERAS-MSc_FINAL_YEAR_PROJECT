import 'dart:async';
import 'dart:convert';
import 'package:ieras_buddy/config.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart'; // Add this
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class CarInfotainmentUI extends StatefulWidget {
  const CarInfotainmentUI({super.key});
  @override
  State<CarInfotainmentUI> createState() => _CarInfotainmentUIState();
}

class _CarInfotainmentUIState extends State<CarInfotainmentUI> {
  GoogleMapController? mapController;
  LatLng? currentPosition;
  StreamSubscription<Position>? positionStream;

  late IOWebSocketChannel channel; // WebSocket channel
  Marker? ambulanceMarker; // To update marker position

  Set<String> alertedAmbulances = {};
  Map<PolylineId, Polyline> polylines = {};
  late BitmapDescriptor ambulanceIcon;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _connectToWebSocket();
    _loadCustomIcons();
    polylines.clear();
  }

  void _loadCustomIcons() async {
    ambulanceIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/img/ambulance.png',
    );
  }

  void _connectToWebSocket() {
    // Replace with your actual backend IP and port
    channel = IOWebSocketChannel.connect('ws://$baseUrl/ws/ambulance/alert/');

    channel.stream.listen((message) async {
      try {
        final data = jsonDecode(message);
        final ambulanceId = data['ambulance_id'].toString();
        final lat = double.parse(data['latitude'].toString());
        final lng = double.parse(data['longitude'].toString());
        final toLat = double.tryParse(data['to_lat'].toString());
        final toLng = double.tryParse(data['to_long'].toString());

        print("➡️ Drawing route from ($lat, $lng) to ($toLat, $toLng)");

        final marker = Marker(
          markerId: MarkerId("ambulance_$ambulanceId"),
          position: LatLng(lat, lng),
          icon: ambulanceIcon,
          infoWindow: InfoWindow(title: "Ambulance $ambulanceId"),
        );

        setState(() {
          ambulanceMarker = marker;
        });

        // 🚨 Draw polyline if destination is provided
        if (toLat != null && toLng != null) {
          List<LatLng> routePoints = await fetchRouteFromOSRM(lat, lng, toLat, toLng);
          setState(() {
            polylines[PolylineId('route_$ambulanceId')] = Polyline(
              polylineId: PolylineId('route_$ambulanceId'),
              points: routePoints,
              color: Colors.red,
              width: 5,
            );
          });
        }

        // 🚨 Proximity check
        if (currentPosition != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            lat,
            lng,
          );

          if (distanceInMeters < 2000 && !alertedAmbulances.contains(ambulanceId)) {
            alertedAmbulances.add(ambulanceId);

            final player = AudioPlayer();
            await player.play(AssetSource('sound/alarm.mp3'));

            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("🚨 Ambulance Alert"),
                  content: Text("Ambulance $ambulanceId is nearby! Please clear the way."),
                  actions: [
                    TextButton(
                      onPressed: () {
                        player.stop();
                        Navigator.pop(context);
                      },
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            }
          }
        }
      } catch (e) {
        print("❌ Error decoding WebSocket message: $e");
      }
    });

  }

  Future<List<LatLng>> fetchRouteFromOSRM(double fromLat, double fromLng, double toLat, double toLng) async {

    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson');

    print("➡️ Drawing route from ($fromLat, $fromLng) to ($toLat, $toLng)");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
    } else {
      print('❌ Failed to load route: ${response.statusCode}');
      return [];
    }
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    await Geolocator.requestPermission();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLng(currentPosition!),
      );
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    channel.sink.close(status.goingAway); // close WebSocket
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            // Left Panel
            Container(
              width: width * 0.4,
              padding: const EdgeInsets.all(8),
              color: Colors.black,
              child: Column(
                children: [
                  Card(
                    color: Colors.grey[850],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundImage: NetworkImage('https://i.pinimg.com/originals/80/69/83/806983d5cd8acd5594e8e5ab0cbf8cd7.jpg'),
                      ),
                      title: const Text('Nihal', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('New message', style: TextStyle(color: Colors.white70)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.play_arrow, color: Colors.white),
                          SizedBox(width: 8),
                          Icon(Icons.reply, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.grey[850],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.album, color: Colors.red),
                      title: const Text('Kannodu - Live', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Job Kurian', style: TextStyle(color: Colors.white70)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.skip_previous, color: Colors.white),
                          SizedBox(width: 8),
                          Icon(Icons.pause, color: Colors.white),
                          SizedBox(width: 8),
                          Icon(Icons.skip_next, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      Icon(Icons.notifications, color: Colors.white, size: 28),
                      Icon(Icons.mic, color: Colors.white, size: 28),
                      Icon(Icons.settings, color: Colors.white, size: 28),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // Right panel (live map)
            Expanded(
              child: currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: currentPosition!,
                  zoom: 16,
                ),
                onMapCreated: (controller) => mapController = controller,
                polylines: Set<Polyline>.of(polylines.values),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('me'),
                    position: currentPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    infoWindow: const InfoWindow(title: 'You'),
                  ),
                  if (ambulanceMarker != null) ambulanceMarker!,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
