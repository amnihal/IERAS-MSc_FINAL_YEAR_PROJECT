import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ieras_buddy/config.dart';

class ReqStatus extends StatefulWidget {
  final ScrollController scrollController;
  const ReqStatus(this.scrollController, {super.key});

  @override
  State<ReqStatus> createState() => _ReqStatusState();
}

class _ReqStatusState extends State<ReqStatus> {
  bool _loading = true;
  String? _status;
  late List<Map<String, dynamic>> steps;

  @override
  void initState() {
    super.initState();
    _loadSavedStatus().then((_) {
      _loadStatusAndSteps();
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

  Future<void> _loadStatusAndSteps() async {
    final prefs = await SharedPreferences.getInstance();
    int? caseId = prefs.getInt('current_case_id_user_$userId');
    caseId ??= prefs.getInt('ongoing_case_id_user_$userId');

    print('$caseId');

    if (caseId == null) {
      // No caseId stored, show no steps or a message
      setState(() {
        _loading = false;
        _status = null;
        steps = [];
      });
      return;
    }

    final url = Uri.parse('http://$emUrl/emergency/emergency_request_status/$caseId/');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;
        setState(() {
          _status = status;
          steps = _buildStepsFromStatus(status);
          _loading = false;
        });
      } else {
        setState(() {
          _status = null;
          steps = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = null;
        steps = [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildStepsFromStatus(String? status) {
    // Define all steps in order
    List<String> allSteps = [
      "Request Sent",
      "Ambulance Assigned",
      "Ambulance En Route",
      "Arrived at Pickup",
      "On the Way to Hospital",
      "Reached Hospital"
    ];

    // Map status strings to steps completed index:
    // You can adjust these mappings based on your backend's status semantics
    int doneIndex = 0;

    switch (status) {
      case 'pending':
        doneIndex = 0;
        break;
      case 'accepted':
        doneIndex = 1;
        break;
      case 'on_route':
        doneIndex = 2;
        break;
      case 'picked':
        doneIndex = 3;
        break;
      case 'to_hospital':
        doneIndex = 4;
        break;
      case 'completed':
        doneIndex = 5;
        break;
      default:
        doneIndex = -1; // no ongoing steps or none
    }

    return List.generate(allSteps.length, (index) {
      return {
        "label": allSteps[index],
        "isDone": index <= doneIndex && doneIndex >= 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    if (steps.isEmpty) {
      return Center(child: Text('No ongoing requests found.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Status'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ListView.builder(
          controller: widget.scrollController,
          itemCount: steps.length,
          itemBuilder: (context, index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            final isDone = step['isDone'] as bool;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column with icon and vertical line
                Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isDone ? Colors.redAccent : Colors.grey[300],
                      child: Icon(
                        isDone ? Icons.check : Icons.radio_button_unchecked,
                        size: 16,
                        color: isDone ? Colors.white : Colors.grey,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Right column with label
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      step['label'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                        color: isDone ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
