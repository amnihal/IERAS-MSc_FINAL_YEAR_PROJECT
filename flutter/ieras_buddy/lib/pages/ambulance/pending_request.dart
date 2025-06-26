import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ieras_buddy/config.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
class PendingRequestsPage extends StatefulWidget {
  const PendingRequestsPage({super.key});

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  List<dynamic> pendingRequests = [];
  bool isLoading = true;
  int? ambulanceId;
  String? ambulanceType;

  @override
  void initState() {
    super.initState();
    _loadSavedStatus();
    fetchPendingRequests();
  }


  Future<void> _loadSavedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedAmbulanceId = prefs.getInt('ambulance_id');
    String? savedAmbulanceType = prefs.getString('ambulance_type');
    setState(() {
      ambulanceId = savedAmbulanceId;
      ambulanceType = savedAmbulanceType ?? '';
    });
  }

  Future<void> fetchPendingRequests() async {

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://$baseUrl/emergency/pending-requests/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Fetched pending requests: $data"); // Debug print
        final myType = ambulanceType?.toLowerCase() ?? '';
        print("Ambulance Type (filter): $myType"); // Debug print

        setState(() {
          pendingRequests = data.where((req) {
            final caseType = req['ambulance_type']?.toLowerCase();
            print("Case Type: $caseType"); // Debug print
            return caseType == myType;
          }).toList();
        });
      } else {
        print('Error: ${response.body}');
      }
    } catch (e) {
      print("Network error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> acceptRequest(int caseId) async {
    try {
      final response = await http.post(
        Uri.parse('http://$baseUrl/vehicle/accept_request/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "case_id": caseId,
          "ambulance_id": ambulanceId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request accepted')),
        );
        Navigator.pop(context, true); // Go back to home
      } else {
        final error = jsonDecode(response.body)["error"];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error")),
      );
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final hospital = request['hospital'];
    final hospitalName = hospital != null ? hospital['name'] ?? 'Not specified' : 'Not specified';

    final double lat = double.tryParse(request['from_lat'].toString()) ?? 0.0;
    final double lng = double.tryParse(request['from_long'].toString()) ?? 0.0;

    const int zoom = 16; // Zoom level for detail, adjust as needed

    int tileX = lonToTileX(lng, zoom);
    int tileY = latToTileY(lat, zoom);

    String tileUrl = "https://tile.openstreetmap.org/$zoom/$tileX/$tileY.png";

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Patient: ${request['patient_condition']}",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: Stack(
                children: [
                  Image.network(
                    tileUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Center(child: Text('Map unavailable')),
                  ),
                  // Simple marker in center (approx)
                  Center(
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text("Hospital: $hospitalName",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => acceptRequest(request['case_id']),
                child: Text('Accept'),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper functions
  int lonToTileX(double lon, int zoom) {
    return ((lon + 180) / 360 * math.pow(2, zoom)).floor();
  }

  int latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180;
    return ((1 -
        math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        math.pow(2, zoom))
        .floor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pending Requests")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : pendingRequests.isEmpty
          ? Center(child: Text("No pending requests."))
          : ListView.builder(
        itemCount: pendingRequests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(pendingRequests[index]),
      ),
    );
  }
}
