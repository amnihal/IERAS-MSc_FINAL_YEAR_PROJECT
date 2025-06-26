import 'dart:convert';
import 'package:ieras_buddy/config.dart';
import 'package:flutter/material.dart';
import 'package:ieras_buddy/pages/user/nearest_hospitals.dart';
import 'package:ieras_buddy/pages/user/request_page.dart';
import 'package:ieras_buddy/pages/user/status_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserHome extends StatelessWidget {
  const UserHome({super.key});



  Future<void> _checkOngoingRequest(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final url = Uri.parse('http://$emUrl/emergency/check_ongoing_request/$userId/');

    try {

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['ongoing'] == true) {

          int caseId = data['case_id'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setInt('ongoing_case_id_user_$userId', caseId);
          print("Saved ongoing_case_id_user_$userId = ${prefs.getInt('ongoing_case_id_user_$userId')}");
          print(caseId);

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text('⚠️Ongoing Request', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),),
              content: Text('You already have an ongoing ambulance request.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AmbulanceRequestPage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check ongoing requests. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'IERAS CONNECT',
          style: TextStyle(
            color: Colors.redAccent.shade100,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 4,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Optional: Clear all stored session data

                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ];
            },
            icon: const Icon(Icons.more_vert, color: Colors.redAccent),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            _buildCPRCard(context),
            SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    context,
                    Icons.phone_in_talk,
                    'Call Ambulance',
                        () => _checkOngoingRequest(context),
                  ),
                  _buildFeatureCard(
                      context, Icons.track_changes, 'Status', () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.6,
                        minChildSize: 0.4,
                        maxChildSize: 0.95,
                        builder: (context, scrollController) =>
                            ReqStatus(scrollController),
                      ),
                    );
                  }),
                  _buildFeatureCard(
                      context, Icons.medical_services, 'First Aid', () {

                  }),
                  _buildFeatureCard(context, Icons.local_hospital,
                      'Nearest Hospitals', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NearestHospitalPage()),
                      );
                    },),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildFeatureCard(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.redAccent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.redAccent),
            SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }


  Widget _buildCPRCard(BuildContext context) {
    return Card(
      color: Colors.white, // White background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Perform CPR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black, // redAccent accent text
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to CPR instruction page if needed
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, // Soft redAccent background
                      foregroundColor: Colors.white, // Dark redAccent text
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Learn more',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Image.asset(
              'assets/img/cpr.png',
              fit: BoxFit.cover,
              height: 100,
            ),
          ),
        ],
      ),
    );
  }
}
