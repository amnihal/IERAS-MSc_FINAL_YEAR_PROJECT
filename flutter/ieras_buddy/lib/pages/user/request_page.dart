import 'package:flutter/material.dart';
import 'package:ieras_buddy/config.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ieras_buddy/pages/user/map_page.dart';
import 'package:http/http.dart' as http;
import 'package:ieras_buddy/pages/user/success_page.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AmbulanceRequestPage extends StatefulWidget {
  const AmbulanceRequestPage({super.key});

  @override
  State<AmbulanceRequestPage> createState() => _AmbulanceRequestPageState();
}

class _AmbulanceRequestPageState extends State<AmbulanceRequestPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController hospitalController = TextEditingController();

  String selectedType = 'Basic';
  String selectedCondition = 'Stable';
  bool isLoadingLocation = false;
  bool isSubmitting = false;



  @override
  void initState() {
    super.initState();
    _loadSavedStatus();
  }

  int? userId;
  Future<void> _loadSavedStatus() async {
    final prefs = await SharedPreferences.getInstance();

    int? savedUserId = prefs.getInt('user_id');
    print('Loaded user_id: $savedUserId');

    setState(() {
      userId = savedUserId;
    });
  }

  @override
  void dispose() {
    fromController.dispose();
    notesController.dispose();
    hospitalController.dispose();
    super.dispose();
  }

  String gpsLoc = '';

  void showWarningDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(200), // dark unfocused background
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), // blur effect
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: EdgeInsets.fromLTRB(24, 12, 24, 0),
            actionsPadding: EdgeInsets.only(right: 12, bottom: 12),
            title: Row(
              children: [
                SizedBox(width: 8),
                Text(
                  'Alert',
                  style: TextStyle(
                    color: Colors.redAccent[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.redAccent[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  Future<void> _openMapPicker() async {
    bool granted = await _requestLocationPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Location permission is required to pick a location')),
      );
      return;
    }
    LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapPickerPage()),
    );

    if (result != null) {
      setState(() {
        gpsLoc = 'Lat: ${result.latitude}, Long: ${result.longitude}';
        fromController.text = 'Selected from map';
      });
    }
  }

  Future<void> _submitRequest() async {
    if (gpsLoc.isEmpty) {
      showWarningDialog(context, "Please select a location from the map.");
      return;
    }

    setState(() => isSubmitting = true);

    final latLongParts =
        gpsLoc.replaceAll('Lat: ', '').replaceAll('Long: ', '').split(',');
    String lat = latLongParts[0].trim();
    String long = latLongParts[1].trim();

    Map<String, dynamic> requestData = {
      'user_id': userId!,
      'from_lat': lat,
      'from_long': long,
      'ambulance_type': selectedType,
      'patient_condition': selectedCondition,
      'additional_notes': notesController.text,
      'hospital_name':
          hospitalController.text.isEmpty ? null : hospitalController.text,
    };

    try {
      final response = await http.post(
        Uri.parse('http://$emUrl/emergency/request-ambulance/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final caseId = responseData['case_id']; // get created case id

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RequestSuccessPage(caseId: caseId),
          ),
        );
      } else {
        print(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request.')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred.')),
      );
    }

    setState(() => isSubmitting = false);
  }

  Future<List<String>> fetchHospitalSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('http://$emUrl/hospital/search_hospital/?q=$query'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => item['name'].toString()).toList();
      }
    } catch (e) {
      print("Error fetching hospitals: $e");
    }
    return [];
  }

  void _showHospitalSearchDialog() async {

    String? selectedHospital = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Search Hospital'),
          content: TypeAheadField<String>(
            suggestionsCallback: (pattern) async {
              if (pattern.length < 2) return [];
              return await fetchHospitalSuggestions(pattern);
            },
            itemBuilder: (context, suggestion) {
              return ListTile(title: Text(suggestion));
            },
            onSelected: (suggestion) {
              Navigator.pop(context, suggestion);
            },
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type hospital name',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );

    if (selectedHospital != null) {
      setState(() {
        hospitalController.text = selectedHospital;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Ambulance',
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: fromController,
              readOnly: true,
              onTap: _openMapPicker,
              decoration: InputDecoration(
                labelText: 'From Location',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.location_on, color: Colors.redAccent),
                suffixIcon: IconButton(
                  icon: Icon(Icons.map, color: Colors.redAccent),
                  onPressed: _openMapPicker,
                ),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              value: selectedType,
              decoration: InputDecoration(
                labelText: 'Ambulance Type',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['Basic', 'Advanced', 'Neonatal']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type,
                          style: TextStyle(color: Colors.black),
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedType = value!),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              value: selectedCondition,
              decoration: InputDecoration(
                labelText: 'Patient Condition',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['Stable', 'Serious', 'Critical']
                  .map((cond) => DropdownMenuItem(
                        value: cond,
                        child: Text(
                          cond,
                          style: TextStyle(color: Colors.black),
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedCondition = value!),
            ),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Additional Notes',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.note, color: Colors.redAccent),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: hospitalController,
              readOnly: true,
              onTap: () => _showHospitalSearchDialog(),
              decoration: InputDecoration(
                labelText: 'Preferred Hospital (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.local_hospital, color: Colors.redAccent),
                suffixIcon: Icon(Icons.search),
              ),
            ),




            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? CircularProgressIndicator(
                      color: Colors.redAccent,
                      strokeWidth: 2,
                    )
                  : Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
