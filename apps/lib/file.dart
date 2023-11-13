import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentification.dart';
import 'connexion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class LoginPageRoute extends MaterialPageRoute {
  LoginPageRoute() : super(builder: (BuildContext context) => Authentication());
}

class ConnexionPageRoute extends MaterialPageRoute {
  ConnexionPageRoute()
      : super(builder: (BuildContext context) => MyHomeePage(title: 'connexion'));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[400],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assests/images/aaaaaa.png',
              width: 150.0,
            ),
            SizedBox(height: 20.0),
            Text(
              'Welcome to Safe Senior',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.0,
              ),
            ),
            SizedBox(height: 30.0),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, LoginPageRoute());
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.blue[900],
                fixedSize: Size(150, 60),
              ),
              child: Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}
