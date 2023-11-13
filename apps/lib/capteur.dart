import 'dart:async';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialisez Firebase
  await initializeNotifications();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyMovingObjectPage(),
    );
  }
}
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
}
class Area {
  final double left;
  final double right;
  final double top;
  final double bottom;
  final String name;

  Area({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.name,
  });
}

class ZonePainter extends CustomPainter {
  final double zoneLeft;
  final double zoneRight;
  final double zoneTop;
  final double zoneBottom;
  final String name;

  ZonePainter({
    required this.zoneLeft,
    required this.zoneRight,
    required this.zoneTop,
    required this.zoneBottom,
    required this.name,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final zoneRect = Rect.fromLTRB(zoneLeft, zoneTop, zoneRight, zoneBottom);
    canvas.drawRect(zoneRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class MyMovingObjectPage extends StatefulWidget {
  @override
  _MyMovingObjectPageState createState() => _MyMovingObjectPageState();
}

class _MyMovingObjectPageState extends State<MyMovingObjectPage> {
  double _xPosition = 0.0;
  double _yPosition = 0.0;
  bool _isMoving = false;
  bool _isolateRunning = false;
  Isolate? _movingIsolate;
  Timer? _detectionTimer; // Déclaration de la variable _detectionTimer
  DateTime? lastEnterTime; // Variable pour enregistrer le dernier moment où l'objet est entré dans une zone
  bool hasCrossedAllZonesAtNight = false;

  final double maxXPosition = 300.0; // Maximum X position (adjust to screen width)
  final double maxYPosition = 500.0; // Maximum Y position (adjust to screen height)
  final double maxDelta = 10.0; // Réduire la plage de déplacement
  final double zoneLeft = 100.0;
  final double zoneRight = 200.0;
  final double zoneTop = 200.0;
  final double zoneBottom = 400.0;
  String currentAreaName = 'Zone non détectée';
  int passesInZoneB = 0;
  List<String> traversedZones = [];

  Map<String, List<DateTime>> zoneTraverseDates = {};
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  List<Area> areas = [

    Area(left: 110, right: 190, top: 250, bottom: 300, name: 'Zone B'),
    Area(left: 30, right: 100, top: 125, bottom: 405, name: 'Zone C'),
    Area(left: 80, right: 40, top: 135, bottom: 200, name: 'Zone O'),
    Area(left: 100, right: 200, top: 200, bottom: 400, name: 'Zone A'),
    // ... ajoutez d'autres zones ici
  ];
  @override
  void initState() {
    super.initState();
    _getInitialPosition();
    _startDetection();
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Utilisez les valeurs d'accélération event.x, event.y, event.z
      // pour détecter une éventuelle chute
      _detectFall(event.x, event.y, event.z);
    });

  }
  void showZoneAlertNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      //'zone_alert_channel',
      'Zone Alert',
      'Alerte lorsque l\'objet traverse la zone A',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await FlutterLocalNotificationsPlugin().show(
      0,
      'Objet dans la zone A',
      'ton personne a traversé la zone A',
      platformChannelSpecifics,
    );
  }
  void _saveTraverseDatesToFirebase() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    for (var zoneName in zoneTraverseDates.keys) {
      List<DateTime> traverseDates = zoneTraverseDates[zoneName]!;

      Map<String, dynamic> data = {
        'zoneName': zoneName,
        'traverseDates': traverseDates.map((date) => date.toIso8601String()).toList(),
      };

      DocumentReference zoneDocument = firestore.collection('ZoneTraverser').doc(zoneName);
      await zoneDocument.set(data);
    }
  }


  void _getInitialPosition() async {
    final _geolocator = Geolocator();
    final double scale = 10.0;
    Position position = await Geolocator.getCurrentPosition();

    setState(() {
      _xPosition = position.latitude / scale;
      _yPosition = position.longitude / scale;
    });
  }

  void _startDetection() {
    _detectionTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _detectArea();
    });
  }
  String formatTraverseDates(List<DateTime> dates) {
    if (dates.isNotEmpty) {
      return dates
          .map((date) => DateFormat('dd/MM/yyyy HH:mm:ss').format(date))
          .join(', ');
    }
    return 'Aucune traversée';
  }

  void _detectArea() {
    String detectedAreaName = 'Zone non détectée';
    DateTime? detectedEnterTime;
    bool hasCrossedAllZones = true;

    for (var zone in areas) {

      if (_isPositionInsideZone(_xPosition, _yPosition, zone)) {
        detectedAreaName = zone.name;
        if (!traversedZones.contains(zone.name)) {
          print("nuitt");
          traversedZones.add(zone.name);
        }
        detectedEnterTime = DateTime.now();
        if (zoneTraverseDates[zone.name] == null) {
          zoneTraverseDates[zone.name] = [];
        }
        zoneTraverseDates[zone.name]!.add(detectedEnterTime);
        if (_isNightTime() ) {
          print("nuit");
          showNighttimeWanderingNotification();
        }
        // Si la zone détectée est la zone B, vérifier le nombre de passages
        if (zone.name == 'Zone A') {
          showZoneAlertNotification();
          print("zoneA");
        } else if (zone.name == 'Zone B') {
          print("zoneB ");
          // Incrémentez le compteur de passages
          passesInZoneB++;
    print("$passesInZoneB");
          // Vérifiez si l'objet a traversé la zone B plus de 6 fois en 2 minutes
          if (passesInZoneB >= 6) {
            print("zoneBC ");
            showZoneBAlertNotification();
            passesInZoneB = 0; // Réinitialisez le compteur
          }
        }

        break;
      }
    }

    // Réinitialisez le compteur de passages pour toutes les autres zones
    if (detectedAreaName == 'Zone non détectée') {
      //passesInZoneB = 0;

    }

    setState(() {
      currentAreaName = detectedAreaName;
      lastEnterTime = detectedEnterTime;
    });
  }


  bool _isPositionInsideZone(double x, double y, Area zone) {
    return x >= zone.left &&
        x <= zone.right &&
        y >= zone.top &&
        y <= zone.bottom;
  }
  bool _isNightTime() {
    DateTime now = DateTime.now();
    int hour = now.hour;
    return hour >= 23 || hour < 6; // Supposons que la nuit soit de 21h à 6h
  }
  void showNighttimeWanderingNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'nighttime_wandering_channel',
      'Nighttime Wandering Notifications',
      //'Notifications for detecting nighttime wandering',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await FlutterLocalNotificationsPlugin().show(
      2,
      'Errance Nocturne',
      'L\'objet semble errer dans toutes les zones pendant la nuit.',
      platformChannelSpecifics,
    );
  }

  void showZoneBAlertNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      //'zone_b_alert_channel', // ID unique de la chaîne de notification
      'Zone C Alert', // Nom de la chaîne de notification
      'Alerte lorsque l\'objet traverse la zone C plus de 6 fois en 2 minutes',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await FlutterLocalNotificationsPlugin().show(
      1, // ID de la notification (doit être unique)
      'Objet dans la zone c', // Titre de la notification
      'L\'objet a traversé la zone c plus de 6 fois en 2 minutes', // Corps de la notification
      platformChannelSpecifics,
    );
  }



  void _detectFall(double x, double y, double z) {
    // Calcul de l'accélération totale en utilisant la racine carrée des carrés des valeurs d'accélération
    double totalAcceleration = sqrt(x * x + y * y + z * z);
print("$totalAcceleration");
    // Définissez un seuil d'accélération pour détecter une chute
    double fallThreshold = 9.8 * 2; // Par exemple, seuil de 2G
    final Random _random = Random();
    //double fallThreshold = _random.nextDouble() * (11.0 - 10) + 9.75;
    print("$fallThreshold");
    if (totalAcceleration > fallThreshold) {

      // Une chute a été détectée, déclenchez l'alerte de chute
      showFallAlertNotification();
    }
  }
  void showFallAlertNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'fall_alert_channel',
      'Fall Alert Notifications',
      //'Notifications for detecting fall events',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await FlutterLocalNotificationsPlugin().show(
      3,
      'Chute Détectée',
      'Une chute a été détectée.',
      platformChannelSpecifics,
    );
  }




  void _startAutoMoveIsolate() async {
    if (!_isolateRunning) {
      _isolateRunning = true;
      final receivePort = ReceivePort();
      _movingIsolate = await Isolate.spawn(_moveObject, receivePort.sendPort);

      receivePort.listen((dynamic data) {
        if (data is MoveInfo) {
          setState(() {
            _xPosition = data.xPosition;
            _yPosition = data.yPosition;
          });
        }
      });
    }
  }

  void _stopAutoMoveIsolate() {
    if (_isolateRunning && _movingIsolate != null) {
      _movingIsolate!.kill(priority: Isolate.immediate);
      _movingIsolate = null;
      _isolateRunning = false;

      _saveTraverseDatesToFirebase();
        // Cette partie du code sera exécutée après que les données ont été enregistrées
        // Vous pouvez également effectuer d'autres opérations ici si nécessaire

    }
  }



  @override
  void dispose() {
    _stopAutoMoveIsolate();
    _detectionTimer?.cancel();
    _accelerometerSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Déplacement automatique d\'un objet'),
      ),
      body: Stack(
        children: [
          Positioned(
            left: _xPosition,
            top: _yPosition,
            child: Icon(
              Icons.location_on,
              color: Colors.red,
              size: 30,
            ),
          ),
          for (var area in areas)
            CustomPaint(
              painter: ZonePainter(
                zoneLeft: area.left,
                zoneRight: area.right,
                zoneTop: area.top,
                zoneBottom: area.bottom,
                name: area.name,
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentAreaName),
                if (lastEnterTime != null)
                  Text('Dernière entrée : ${DateFormat('HH:mm:ss').format(lastEnterTime!)}'),
                for (var area in areas)
                  Text('${area.name}: ${formatTraverseDates(zoneTraverseDates[area.name] ?? [])}'),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isMoving = !_isMoving;
                    if (_isMoving) {
                      _startAutoMoveIsolate();
                    } else {
                      _stopAutoMoveIsolate();
                    }
                  });
                },
                child: Text(_isMoving ? 'Arrêter' : 'Démarrer'),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Position actuelle : Lat: $_xPosition, Long: $_yPosition'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MoveInfo {
  double xPosition;
  double yPosition;

  MoveInfo(this.xPosition, this.yPosition);
}

void _moveObject(SendPort sendPort) {
  final Random _random = Random();
  double xPosition = 0.0;
  double yPosition = 0.0;
  double maxDelta = 10.0;
  while (true) {
    sendPort.send(MoveInfo(xPosition, yPosition));

    final deltaX = _random.nextDouble() * maxDelta * 2 - maxDelta;
    final deltaY = _random.nextDouble() * maxDelta * 2 - maxDelta;

    xPosition += deltaX;
    yPosition += deltaY;

    if (xPosition > 300.0) {
      xPosition = 0.0;
    } else if (xPosition < 0) {
      xPosition = 300.0;
    }

    if (yPosition > 500.0) {
      yPosition = 0.0;
    } else if (yPosition < 0) {
      yPosition = 500.0;
    }

    Future.delayed(Duration(hours: 1)); // Utilisez milliseconds ici, pas hours
  }
}
