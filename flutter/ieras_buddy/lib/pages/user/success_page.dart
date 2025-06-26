import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ieras_buddy/config.dart';
import 'package:ieras_buddy/pages/user/user_home.dart';
import 'package:shared_preferences/shared_preferences.dart';


class RequestSuccessPage extends StatefulWidget {
  final int caseId;

  const RequestSuccessPage({super.key, required this.caseId});

  @override
  State<RequestSuccessPage> createState() => _RequestSuccessPageState();
}

class _RequestSuccessPageState extends State<RequestSuccessPage> {
  Timer? _timer;
  bool _isAccepted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedStatus();
    _startPolling();
    // Call the async function without awaiting
    Future.delayed(Duration.zero, () {
      saveCurrentCaseId(widget.caseId);
    });
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

  Future<void> saveCurrentCaseId(int caseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_case_id_user_$userId', caseId);
    print(caseId);
  }

  void _startPolling() {
    _timer = Timer.periodic(Duration(seconds: 5), (_) async {
      if (!_isAccepted) {
        await _checkRequestStatus();
      }
    });
  }

  Future<void> _checkRequestStatus() async {
    setState(() {
      _isLoading = true;
    });


    final url = Uri.parse('http://$emUrl/emergency/emergency_request_status/${widget.caseId}/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];

        if (status == 'accepted' || status == 'ongoing') {
          setState(() {
            _isAccepted = true;
          });



          _timer?.cancel();

          // Delay for UX
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => UserHome()),
                    (route) => false,
              );
            }
          });
        }
      } else {
        print('Failed to fetch status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking status: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _cancelRequest() async {
    final url = Uri.parse('http://$emUrl/emergency/cancel_request/${widget.caseId}/');

    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request cancelled')),
          );
          _timer?.cancel();
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to cancel request')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling request')),
      );
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(height: 16),

              // Ambulance image
              Center(
                child: Image.asset(
                  'assets/img/ambulance.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 40),

              Text(
                _isAccepted
                    ? 'Ambulance accepted your request!'
                    : 'Contacting Ambulance Drivers nearby...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 24),

              if (_isLoading && !_isAccepted)
                Center(child: CircularProgressIndicator(color: Colors.white)),

              Text(
                _isAccepted
                    ? 'Redirecting to live tracking...'
                    : 'You can cancel this request within 30 Seconds',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),

              Spacer(),

              if (!_isAccepted)
                Center(
                  child: TextButton(
                    onPressed: _cancelRequest,
                    child: Text(
                      'Cancel request',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

              if (!_isAccepted) SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
