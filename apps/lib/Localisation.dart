import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apps/MyHomePage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';




class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location',
      home: const LocalisationPage(),
    );
  }
}

class LocalisationPage extends StatefulWidget {
  const LocalisationPage({Key? key}) : super(key: key);

  @override
  _LocalisationPageState createState() => _LocalisationPageState();
}

class _LocalisationPageState extends State<LocalisationPage> {
  late String lat ='';
  late String long='';
  late String locationMessage = '';

  void _liveLocation() {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      lat = position.latitude.toString();
      long = position.longitude.toString();
      setState(() {
        locationMessage = 'Latitude: $lat , Longitude: $long';
      });
    });
  }

  void _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("Permission not given");
      LocationPermission asked = await Geolocator.requestPermission();
    } else {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      print("Latitude: ${currentPosition.latitude.toString()}");
      print("Longitude: ${currentPosition.longitude.toString()}");

      setState(() {
        lat = '${currentPosition.latitude}';
        long = '${currentPosition.longitude}';
        locationMessage = 'Latitude: $lat , Longitude: $long';
      });
    }
  }
  void _openMap(String lat, String long) async {
    String googleURL = 'https://www.google.com/maps/search/?api=1&query=$lat,$long';
    print('affichage');
    if (await canLaunch(googleURL)) {
      await launch(googleURL);
      print('L\'URL peut être lancée');
    } else {
      Fluttertoast.showToast(
        msg: 'Could not launch $googleURL',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localisation'),
        backgroundColor: Colors.purple,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed:() {
                    _getCurrentLocation();
                    _liveLocation();},
                    child:const Text("Get current position"),

                  ),
              const SizedBox(height: 20),
              Text(
                locationMessage,
                style: const TextStyle(fontSize: 16),
              ),
              ElevatedButton(
                onPressed:(){
                  _openMap(lat,long);
                  print('open');
                },
                child: const Text('open Google Map'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}