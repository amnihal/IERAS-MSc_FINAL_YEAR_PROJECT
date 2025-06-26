import 'dart:async';
import 'dart:convert';
import 'package:ieras_buddy/config.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ieras_buddy/pages/ambulance/pending_request.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  _DriverHomePageState createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final Completer<GoogleMapController> _controller = Completer();
  String? _mapStyle;
  bool isOnline = true;
  Map<String, dynamic>? ongoingCase;
  late IOWebSocketChannel channel;
  bool isLoading = true;
  // bool isRouteLoading = false;
  BitmapDescriptor? _patientIcon;
  BitmapDescriptor? _ambulanceIcon;
  // bool _hasStarted = false;
  String currentStatus = ""; // Tracks which button/status is active
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? ambulanceId;
  String? ambulanceType;

  final Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  double? etaInMinutes;

  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(11.343637, 75.832604),
    zoom: 16.0,
  );

  @override
  void initState() {
    super.initState();
    // clearAllPreferences();
    _loadMapStyle();
    _loadCustomMarker();
    _loadSavedStatus().then((_) {
      _connectWebSocket();  // Now ambulanceId is available
      _fetchOngoingCase();
    });// Now ambulanceId is available
  }
  // Future<void> clearAllPreferences() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.clear();
  // }

  Future<void> _loadSavedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    currentStatus = prefs.getString('case_status') ?? '';
    int? savedAmbulanceId = prefs.getInt('ambulance_id');
    String? savedAmbulanceType = prefs.getString('ambulance_type');
    print('Loaded ambulance_id: $savedAmbulanceId');
    print('Loaded ambulance_type: $savedAmbulanceType');

    setState(() {
      ambulanceId = savedAmbulanceId;
      ambulanceType = savedAmbulanceType ?? '';
    });
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/map_style.json');
    setState(() {
      _mapStyle = style;
    });
  }

  void _connectWebSocket() {
    try {
      channel = IOWebSocketChannel.connect('ws://$baseUrl/ws/ambulance/');
      print('😊WebSocket message received with ambulanceId: $ambulanceId'); // Debug
      channel.stream.listen((message) {

        final data = jsonDecode(message);

        final caseAmbulanceType = data['ambulance_type'];
        final myAmbulanceType = ambulanceType;

        if (isOnline &&
            ongoingCase == null &&
            caseAmbulanceType == myAmbulanceType) {
          print('🚨 Emergency Case: $data');
          _showIncomingRequestDialog(data);
        } else {
          print('🔕 Ignored: Not for $ambulanceType ambulance');
        }
      });
    } catch (e) {
      print("WebSocket Error: $e");
    }
  }

  Future<void> _loadCustomMarker() async {
    final patientBitmap = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/img/marker.png',
    );

    // final ambulanceBitmap = await BitmapDescriptor.asset(
    //   const ImageConfiguration(size: Size(48, 48)),
    //   'assets/img/ambulance.png', // Use your current marker icon path
    // );

    setState(() {
      _patientIcon = patientBitmap;
      // _ambulanceIcon = ambulanceBitmap;
    });
  }

  void _showIncomingRequestDialog(Map<String, dynamic> request) {
    final hospital = request['hospital'];
    final hospitalName = hospital != null
        ? hospital['hname'] ?? 'Not specified'
        : 'Not specified';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '🚨 Emergency Request',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Patient condition: ${_formatCondition(request["patient_condition"])}"),
            SizedBox(height: 8),
            Text("Hospital: $hospitalName"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Ignore'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final response = await http.post(
                Uri.parse('http://$baseUrl/vehicle/accept_request/'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  "case_id": request["case_id"],
                  "ambulance_id": ambulanceId,
                }),
              );

              if (response.statusCode == 200) {
                // final caseData = jsonDecode(response.body);
                await _fetchOngoingCase();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Request Accepted!")),
                );
              } else {
                final error = jsonDecode(response.body)["error"];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $error")),
                );
              }
            },
            child: Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOngoingCase() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://$baseUrl/vehicle/ongoing-case/$ambulanceId/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          ongoingCase = data;
        });
        _updateMapMarker(data);
        _calculateETA(); // Trigger ETA calculation
      } else if (response.statusCode == 204) {
        setState(() {
          ongoingCase = null;
          _markers.clear();
        });
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Error fetching ongoing case: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildOngoingCaseCard() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
        ),
        child: ongoingCase == null
            ? Text(
          'No ongoing cases',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🚑 Ongoing Case",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Patient: ${ongoingCase!["patient_condition"]}"),
            SizedBox(height: 4),
            Text("Contact: ${ongoingCase!["patient_contact"]}"),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final Uri callUri = Uri(scheme: 'tel', path: ongoingCase!["patient_contact"]);
                await launchUrl(callUri);
              },
              icon: Icon(Icons.call, color: Colors.white),
              label: Text("Call Patient", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            Text(etaInMinutes != null
                ? "ETA: ${etaInMinutes!.toStringAsFixed(0)} min"
                : "ETA: Calculating..."),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                statusButton("Start", "on_route"),
                statusButton("Picked", "picked"),
                statusButton("Completed", "completed"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCondition(String? raw) {
    return raw?.replaceAll("_", " ").toUpperCase() ?? "UNKNOWN";
  }

  Future<void> _updateMapMarker(Map<String, dynamic> caseData) async {
    double lat = double.tryParse(caseData['from_lat'].toString()) ?? 0.0;
    double lng = double.tryParse(caseData['from_long'].toString()) ?? 0.0;

    final marker = Marker(
      markerId: MarkerId("emergency_location"),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: "Patient Location"),
      icon: _patientIcon ?? BitmapDescriptor.defaultMarker,
    );

    setState(() {
      _markers = {marker};
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
  }

  Future<void> fetchAndPrintRoutePoints(
      double fromLat, double fromLng, double toLat, double toLng, {
        int retries = 3,
      }) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson';

    int attempt = 0;

    while (attempt < retries) {
      try {
        attempt++;
        final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final durationInSeconds = data['routes'][0]['duration'];

          List<LatLng> routePoints = coords
              .map((point) => LatLng(point[1] as double, point[0] as double))
              .toList();

          setState(() {
            etaInMinutes = (durationInSeconds / 60).roundToDouble();
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: PolylineId('route_polyline'),
              color: Colors.blue,
              width: 6,
              points: routePoints,
            ));
          });

          final GoogleMapController controller = await _controller.future;
          LatLngBounds bounds = _boundsFromLatLngList(routePoints);
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));

          // Success, exit the retry loop
          break;
        } else {
          print("Failed to fetch route: ${response.statusCode}");
          // Optionally break here if you don't want to retry on HTTP errors
          break;
        }
      } catch (e) {
        print("Attempt $attempt failed: $e");
        if (attempt >= retries) {
          print("Max retries reached. Giving up.");
          // Optionally notify the user or handle failure
        } else {
          // Wait a bit before retrying (exponential backoff or fixed delay)
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }
  }

  Future<void> _calculateETA() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final fromLat = position.latitude;
      final fromLng = position.longitude;
      final toLat = double.parse(ongoingCase!["from_lat"].toString());
      final toLng = double.parse(ongoingCase!["from_long"].toString());

      // Add ambulance marker
      final ambulanceMarker = Marker(
        markerId: MarkerId("ambulance"),
        position: LatLng(fromLat, fromLng),
        infoWindow: InfoWindow(title: "Ambulance"),
        icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarker,
      );

      setState(() {
        _markers.add(ambulanceMarker);
      });

      await fetchAndPrintRoutePoints(fromLat, fromLng, toLat, toLng);
    } catch (e) {
      print('Error getting location for ETA: $e');
    }
  }

  Future<void> _calculateETAH() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final fromLat = position.latitude;
      final fromLng = position.longitude;
      final toLat = double.parse(ongoingCase!["to_lat"].toString());
      final toLng = double.parse(ongoingCase!["to_long"].toString());


      // Add ambulance marker
      final ambulanceMarker = Marker(
        markerId: MarkerId("ambulance"),
        position: LatLng(fromLat, fromLng),
        infoWindow: InfoWindow(title: "Ambulance"),
        icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarker,
      );

      setState(() {
        _markers.add(ambulanceMarker);
      });

      await fetchAndPrintRoutePoints(fromLat, fromLng, toLat, toLng);
    } catch (e) {
      print('Error getting location for ETA: $e');
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double x0 = list[0].latitude;
    double x1 = list[0].latitude;
    double y0 = list[0].longitude;
    double y1 = list[0].longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(
      northeast: LatLng(x1, y1),
      southwest: LatLng(x0, y0),
    );
  }

  Future<void> _sendLiveLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lng = position.longitude;

      await _sendAmbulanceLocationToBackend(lat, lng);
    } catch (e) {
      print('Error sending live location: $e');
    }
  }

  Timer? _locationTimer;

  void _startLiveLocationUpdates() {
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _sendLiveLocation();
    });
  }

  void _stopLiveLocationUpdates() {
    _locationTimer?.cancel();
  }

  Future<void> _sendAmbulanceLocationToBackend(double lat, double lng) async {
    try {
      final toLat = double.parse(ongoingCase!["to_lat"].toString());
      final toLng = double.parse(ongoingCase!["to_long"].toString());

      final response = await http.post(
        Uri.parse('http://$baseUrl/vehicle/ambulance/update-location/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ambulance_id': ambulanceId,
          'latitude': lat,
          'longitude': lng,
          'to_lat': toLat,
          'to_long': toLng,
        }),
      );

      if (response.statusCode == 200) {
        print("Ambulance location sent successfully");
      } else {
        print("Failed to send location: ${response.statusCode}");
      }
    } catch (e) {
      print("Error sending location: $e");
    }
  }

  Future<void> updateCaseStatus(String newStatus) async {
    final caseId = ongoingCase?["case_id"];
    if (caseId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('case_status', newStatus);

    setState(() {
      currentStatus = newStatus;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$baseUrl/vehicle/update_case_status/$caseId/$newStatus/'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status updated to '$newStatus'.")),
        );

        if (newStatus == "on_route") {
          _calculateETA();
          // _startSendingLocationUpdates();
        }

        if (newStatus == "picked") {
          setState(() {
            _markers.clear();
            _polylines.clear();
            etaInMinutes = null;
          });
          _startLiveLocationUpdates();
          _calculateETAH();
        }

        // ✅ Handle completed status
        if (newStatus == "completed") {
          _stopLiveLocationUpdates();

          // _stopSendingLocationUpdates();
          await prefs.remove('case_status');
          await prefs.remove('ongoing_case');
          newStatus = '';
          currentStatus = '';

          setState(() {
            ongoingCase = null;
            _markers.clear();
            _polylines.clear();
            etaInMinutes = null;
          });

          await _fetchOngoingCase(); // Refresh state
        }
      } else {
        print("Error updating status: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status")),
        );
      }
    } catch (e) {
      print("Exception during status update: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error while updating status")),
      );
    }
  }

  Widget statusButton(String label, String statusValue) {
    bool isActive = currentStatus == statusValue;
    bool isPrevious = _isPreviousStatus(statusValue);

    return ElevatedButton(
      onPressed: (isActive || !isPrevious)
          ? null
          : () async {
        await updateCaseStatus(statusValue);
        // Delay to visually highlight the button before moving on
        await Future.delayed(Duration(seconds: 2));
        setState(() {}); // Trigger UI refresh
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.black : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.grey : Colors.blueAccent,
        ),
      ),
    );
  }

  bool _isPreviousStatus(String statusValue) {
    final statusOrder = ["on_route", "picked", "completed"];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final targetIndex = statusOrder.indexOf(statusValue);

    return targetIndex == currentIndex + 1;
  }

  // StreamSubscription<Position>? _positionStreamSubscription;
  //
  // void _startSendingLocationUpdates() {
  //   const LocationSettings locationSettings = LocationSettings(
  //     accuracy: LocationAccuracy.high,
  //     distanceFilter: 10, // Update when moved 10 meters
  //   );
  //
  //   _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
  //       .listen((Position position) {
  //     if (position != null && channel != null) {
  //       final locationData = {
  //         "ambulance_id": ambulanceId,
  //         "latitude": position.latitude,
  //         "longitude": position.longitude,
  //         "timestamp": DateTime.now().toIso8601String(),
  //       };
  //
  //       channel.sink.add(jsonEncode(locationData));
  //       print("Sent location update: $locationData");
  //     }
  //   });
  // }
  //
  // void _stopSendingLocationUpdates() {
  //   _positionStreamSubscription?.cancel();
  // }


  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('IERAS - Driver'),
        actions: [
          Switch(
            value: isOnline,
            onChanged: (val) => setState(() => isOnline = val),
            activeColor: Colors.green,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              isOnline ? Icons.check_circle : Icons.cancel,
              color: isOnline ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            style: _mapStyle,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
          ),
          _buildOngoingCaseCard(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 1) {
            final accepted = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PendingRequestsPage()),
            );

            if (accepted == true) {
              await _fetchOngoingCase(); // Refresh ongoing case on Home page
            }

            setState(() {
              _selectedIndex = index;
            });
          }else if (index == 2) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                  SizedBox(height: 10),
                  Text('Driver Name', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
