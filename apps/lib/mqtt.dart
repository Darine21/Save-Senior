import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Position Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Position? _previousPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Add this line to get initial location
    _startPositionMonitoring();
  }

  void _startPositionMonitoring() {
    Timer.periodic(Duration(minutes: 5), (timer) async {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      print('Current Position: ${position.latitude}, ${position.longitude}');
      _checkForUnusualActivity(position);
    });
  }

  void _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    print('Initial Position: ${position.latitude}, ${position.longitude}');
    _previousPosition = position;
  }

  void _checkForUnusualActivity(Position currentPosition) {
    if (_previousPosition == null) {
      _previousPosition = currentPosition;
      return;
    }

    double distance = Geolocator.distanceBetween(
      _previousPosition!.latitude,
      _previousPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    double distanceThreshold = 50.0;

    print('Distance: $distance');

    if (distance > distanceThreshold) {
      print('Unusual activity detected!');
      _triggerAlarm();
    }

    _previousPosition = currentPosition;
  }

  void _triggerAlarm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alarm!'),
        content: Text('Unusual activity detected.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _manualCheckForUnusualActivity() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    print('Manual Check Position: ${position.latitude}, ${position.longitude}');
    _checkForUnusualActivity(position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Position Monitoring'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Position Monitoring App'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _manualCheckForUnusualActivity,
              child: Text('Check for Unusual Activity'),
            ),
          ],
        ),
      ),
    );
  }
}
