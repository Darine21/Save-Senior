import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:typed_data/typed_buffers.dart'; // Ajoutez cette ligne pour résoudre l'erreur "typed.Uint8Buffer"
import 'package:path/path.dart' as path;
import 'sss.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

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

class Character {
  double x; // Coordonnée x du personnage
  double y; // Coordonnée y du personnage

  Character({required this.x, required this.y});
}

class PhotoDisplayPainter extends CustomPainter {
  final List<Rect> zones;
  final List<String> zoneNames;
  final double scale; // Ajoutez cette ligne
  final Character character; // Ajoutez cette ligne
  final Rect scaledZone; // Remove the duplicate declaration
  final List<bool> zoneEntered; // Add this line

  PhotoDisplayPainter(this.zones, this.zoneNames, this.scale, {required this.character, required this.zoneEntered})
      : scaledZone = Rect.fromLTRB(
    zones.first.left / scale,
    zones.first.top / scale,
    zones.first.right / scale,
    zones.first.bottom / scale,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final markerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    for (var i = 0; i < zones.length; i++) {
      final zone = zones[i];
      final zoneName = zoneNames[i];

      // Draw the zone rectangle and marker
      final scaledZone = Rect.fromLTRB(
        zone.left / scale,
        zone.top / scale,
        zone.right / scale,
        zone.bottom / scale,
      );

      canvas.drawRect(scaledZone, paint);

      // Draw a marker at the bottom-right corner of the zone
      final centerX = scaledZone.right;
      final centerY = scaledZone.bottom;
      final markerRadius = 10.0;
      canvas.drawCircle(Offset(centerX, centerY), markerRadius, markerPaint);

      // Draw the text (zone number) inside the marker
      final zoneNumber = (i + 1).toString();


      // Draw the text below the zone rectangle

      final textPainterCoord = TextPainter(
        text: TextSpan(
          text: 'Zone ${i + 1}\nName: $zoneName\nSurface: ${_calculateSurface(zone).toStringAsFixed(2)}',
          style: zoneEntered[i] ? TextStyle(color: Colors.red) : TextStyle(color: Colors.blue),
        ),

      );
      textPainterCoord.layout();
      final textXCoord = centerX - textPainterCoord.width / 2;
      final textYCoord = centerY + markerRadius * 1.5; // Placez le texte en dessous du marqueur
      //textPainterCoord.paint(canvas, Offset(textXCoord, textYCoord));

    }


  }
  bool _isCharacterInZone(Character character, Rect zone) {
    // Check if the character's position is inside the zone
    return (character.x >= zone.left && character.x <= zone.right &&
        character.y >= zone.top && character.y <= zone.bottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  double _calculateSurface(Rect zone) {
    return zone.width * zone.height;
  }
}

class PhotoDisplayPage extends StatefulWidget {
  final String selectedImagePath;
  final List<Rect> selectedZones;
  final List<String> zoneNames;
  final double scale;

  PhotoDisplayPage({
    Key? key,
    required this.selectedImagePath,
    required this.selectedZones,
    required this.zoneNames,
    required this.scale,
  }) : super(key: key);

  @override
  _PhotoDisplayPageState createState() => _PhotoDisplayPageState();
}

class _PhotoDisplayPageState extends State<PhotoDisplayPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _destinationX = 0;
  double _destinationY = 0;
  int currentZoneIndex = 0;
  bool isWatching = false;
  String currentAreaName = 'Undetected area';
  Map<String, List<DateTime>> zoneTraverseDates = {};
  MqttClient? client; // Déclarez une instance de MqttClient
  StreamSubscription? mqttListen;
  static double scale = 10.0;
  double receivedX = 0.0;
  double receivedY = 0.0;
  double currentLatitude = 0.0;
  double currentLongitude = 0.0;
  bool showPositionMarker = false;
  double sentX = 0.0;
  double sentY = 0.0;
  double photoWidth = 400.0; // Replace with the actual width of your photo
  double photoHeight = 400.0;
  List<Rect> selectedZones =[];
  List<String> zoneNames = [];
  List<Area> zonesData = [];
  Timer? _detectionTimer; // Déclaration de la variable _detectionTimer
  DateTime? lastEnterTime;
  Offset initialPosition = Offset(0, 0);

  final Character character = Character(x: 0, y: 0);
  List<bool> zoneEntered = [];
  int hours = 1;
  Timer? _moveToNextZoneTimer; // Ajouter cette variable pour le planificateur
  Isolate? _isolate;
  ReceivePort? _receivePort;
  double _xPosition = 0.0;
  double _yPosition = 0.0;
  bool _isMoving = false;
  bool _isolateRunning = false;
  Isolate? _movingIsolate;
  final double maxXPosition = 300.0; // Maximum X position (adjust to screen width)
  final double maxYPosition = 500.0; // Maximum Y position (adjust to screen height)
  final double maxDelta = 10.0;
  List<Area> areas = [];
  int passesInZoneB = 0;
  List<String> traversedZones = [];
  @override
  void initState() {
    super.initState();
    initMqtt();
    initializeNotifications();
    // Appel de la méthode statique initMqtt de la classe MqttService
    trackUserPosition();
    _getInitialPosition();
    _startDetection();

    zoneEntered = List.filled(widget.selectedZones.length, false);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(hours: hours),
    )..addListener(() {
      setState(() {
        character.x = lerpDouble(character.x, _destinationX, _controller.value)!;
        character.y = lerpDouble(character.y, _destinationY, _controller.value)!;
      });
    });
    for (int i = 0; i < widget.selectedZones.length; i++) {
      final zone = widget.selectedZones[i];
      final zoneName = widget.zoneNames[i];

      zonesData.add(Area(
        left: zone.left,
        right: zone.right,
        top: zone.top,
        bottom: zone.bottom,
        name: zoneName,
      ));
    }
    for (int i = 0; i < zonesData.length; i++) {
      final area = zonesData[i];
      areas.add(Area(
        left: area.left,
        right: area.right,
        top: area.top,
        bottom: area.bottom,
        name: area.name,
      ));
    }

    _initIsolate();
  }
  void _getInitialPosition() async {
    final _geolocator = Geolocator();
    final double scale= 10.0;
    Position position = await Geolocator.getCurrentPosition();


    setState(() {
      _xPosition = position.latitude /scale;
      _yPosition = position.longitude /scale;
    });
  }
  void _startDetection() {
    _detectionTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _detectArea();
    });
  }
  String _formatTraverseDates(String zoneName) {
    List<DateTime>? traverseDates = zoneTraverseDates[zoneName];
    if (traverseDates != null && traverseDates.isNotEmpty) {
      return traverseDates
          .map((date) => DateFormat('dd/MM/yyyy HH:mm:ss').format(date))
          .join(', ');
    }
    return 'No crossing';
  }
  void _saveTraverseDatesToFirebase() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    for (var zoneName in zoneTraverseDates.keys) {
      List<DateTime> traverseDates = zoneTraverseDates[zoneName]!;

      Map<String, dynamic> data = {
        'zoneName': zoneName,
        'traverseDates': traverseDates.map((date) => date.toIso8601String()).toList(),
      };

      DocumentReference zoneDocument = firestore.collection('ZooneTraverser').doc(zoneName);
      await zoneDocument.set(data);
    }
  }
  void _initIsolate() async {
    _receivePort = ReceivePort();
    //Isolate.spawn<void>(simulatePositionIsolate, _receivePort!.sendPort);
    _receivePort!.listen((message) {
      if (message is Map) {
        double receivedX = message['receivedX'];
        double receivedY = message['receivedY'];

        setState(() {
          currentLatitude = receivedY / (scale * photoHeight);
          currentLongitude = receivedX / (scale * photoWidth);

          this.receivedX = receivedX;
          this.receivedY = receivedY;

          // Update the character's position
          character.x = receivedX;
          character.y = receivedY;
        });
      }
    });

  }


  void _closeIsolate() {
    _receivePort?.close();
    _isolate?.kill();
  }

  void trackUserPosition() async {
    while (true) {
      Position position = await Geolocator.getCurrentPosition();
      currentLatitude = position.latitude /scale;
      currentLongitude = position.longitude /scale ;

      double planX = convertToPlanX(currentLongitude);
      double planY = convertToPlanY(currentLatitude);

      sendPositionToMQTT(planX, planY);

      await Future.delayed(Duration(milliseconds: 5000));
    }
  }
  void simulatePositionIsolate(SendPort sendPort) {
    final random = Random();
    double latitude = 0.5; // Position initiale à l'intérieur de la photo
    double longitude = 0.5; // Position initiale à l'intérieur de la photo

    Timer.periodic(Duration(seconds: 1), (timer) {
      double simulatedLatitude = (random.nextDouble() * 2 - 1) * 0.05; // Changement de latitude simulé (ajusté aux dimensions de la photo)
      double simulatedLongitude = (random.nextDouble() * 2 - 1) * 0.05; // Changement de longitude simulé (ajusté aux dimensions de la photo)

      latitude = (latitude + simulatedLatitude).clamp(0.0, 1.0); // Limiter pour rester à l'intérieur des limites de la photo
      longitude = (longitude + simulatedLongitude).clamp(0.0, 1.0); // Limiter pour rester à l'intérieur des limites de la photo

      double receivedX = longitude * scale * photoWidth; // Ajusté aux dimensions de la photo
      double receivedY = latitude * scale * photoHeight; // Ajusté aux dimensions de la photo

      sendPort.send({'receivedX': receivedX, 'receivedY': receivedY});
    });
  }


  void _detectArea() {
    DateTime? detectedEnterTime;

    for (var zone in areas) {
      if (_isPositionInsideZone(_xPosition, _yPosition, zone)) {
        detectedEnterTime = DateTime.now();
        if (zoneTraverseDates[zone.name] == null) {
          zoneTraverseDates[zone.name] = [];
        }
        zoneTraverseDates[zone.name]!.add(detectedEnterTime);

        if (_isNightTime()) {
          showNighttimeWanderingNotification();
        }

        if (zone.name == 'kitchen') {
          showZoneAlertNotification();
        } else if (zone.name == 'toilette') {
          passesInZoneB++;
          print("$passesInZoneB");
          if (passesInZoneB >= 6) {
            showZoneBAlertNotification();
            passesInZoneB = 0;
          }
        }
      }
    }

    setState(() {
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
      'bathroom Alert', // Nom de la chaîne de notification
      'Alerte lorsque l\'objet traverse la bathroom',
      importance: Importance.max,
      priority: Priority.high,

    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await FlutterLocalNotificationsPlugin().show(
      1, // ID de la notification (doit être unique)
      'Objet dans la zone bathroom', // Titre de la notification
      'L\'objet a traversé la zone c plus de 6 fois en 2 minutes', // Corps de la notification
      platformChannelSpecifics,
    );
  }
  void showZoneAlertNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      //'zone_alert_channel',
      'Zone Alert',
      'Alerte lorsque l\'objet traverse la zone kitchen',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await FlutterLocalNotificationsPlugin().show(
      0,
      'Objet dans kitchen',
      'ton personne a traversé la zone kitchen',
      platformChannelSpecifics,
    );
  }



  void sendPositionToMQTT(double x, double y) async {
    while (client == null || client!.connectionStatus!.state != MqttConnectionState.connected) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString('Position: X=$x, Y=$y');

    final topic = 'user_position';

    try {
      client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
      print( "Position: X=$x, Y=$y");
      print('Position sent via MQTT');
      sentX = x;
      sentY = y;
      setState(() {});
    } catch (e) {
      print('Failed to send position via MQTT: $e');
    }
  }

  double convertToPlanY(double latitude) {
    // Implémentez votre logique de conversion ici
    // par exemple : retournez une valeur en pixels en fonction de la latitude
    return latitude / scale; // Remplacez cette ligne par votre logique
  }
  double convertToPlanX(double longitude) {
    // Implémentez votre logique de conversion ici
    // par exemple : retournez une valeur en pixels en fonction de la longitude
    return longitude / scale; // Remplacez cette ligne par votre logique
  }
  void disconnect() {
    if (client != null && client!.connectionStatus!.state == MqttConnectionState.connected) {
      client!.disconnect();
    }
  }

  void onConnected() {
    print('Connected');
    final builder = MqttClientPayloadBuilder();
    builder.addString('Hello mr/Mme');
    client!.publishMessage('topic1', MqttQos.atMostOnce, builder.payload!);
    client!.subscribe('topic1', MqttQos.atMostOnce);

  }


  void onDisconnected() {
    print('Disconnected');
    client = null; // Réinitialiser le client MQTT après la déconnexion
  }

  void onSubscribeSuccess(String? topic) {
    print('Subscribed to topic: $topic');
  }

  void onSubscribeFail(String topic) {
    print('Failed to subscribe to topic: $topic');
  }

  void onUnsubscribed(String? topic) {
    print('Unsubscribed from topic: $topic');
  }

  void pong() {
    print('Ping response received');
  }

  void initMqtt() {
    if (client == null || client!.connectionStatus!.state == MqttConnectionState.disconnected) {
      client = MqttServerClient('broker.emqx.io', 'flutter_client');
      client!.port = 1883;
      client!.logging(on: true);
      client!.onConnected = onConnected;
      client!.onDisconnected = onDisconnected;
      client!.onUnsubscribed = onUnsubscribed;
      client!.onSubscribed = onSubscribeSuccess;
      client!.onSubscribeFail = onSubscribeFail;
      client!.pongCallback = pong;

      try {
        client!.connect();
        print("connecter");
        final builder = MqttClientPayloadBuilder();
        builder.addString('Hello, MQTT!');

        client!.publishMessage('topic1', MqttQos.atMostOnce, builder.payload!);
        //client!.publishMessage('topic1', MqttQos.atMostOnce, builder.payload!);

      } catch (e) {
        print('Failed to connect to MQTT broker: $e');
      }
    } else {
      print('MQTT client is already connecting or connected');
    }
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage? message = c[0].payload as MqttPublishMessage?;
      if (message != null) {
        final payload =
        MqttPublishPayload.bytesToStringAsString(message.payload.message);

        print('Received message: $payload from topic: ${c[0].topic}>');
      }
    });
  }
  void printZoneData(List<Area> zonesData) {
    for (int i = 0; i < zonesData.length; i++) {
      final area = zonesData[i];
      print('Zone ${i + 1}');
      print('Name: ${area.name}');
      print('Coordinates: Left:${area.left.toStringAsFixed(2)}, Top:${area.top.toStringAsFixed(2)}, Right:${area.right.toStringAsFixed(2)}, Bottom:${area.bottom.toStringAsFixed(2)}');
      //print('Surface: ${_calculateSurface(area).toStringAsFixed(2)}');
      print('----------------------');
    }
  }
  void onClose() {
    if (client != null && client!.connectionStatus!.state == MqttConnectionState.connected) {
      client!.disconnect();
    }
  }
  void moveToDestination(double x, double y) {
    setState(() {
      _destinationX = x;
      _destinationY = y;
    });

    _controller.reset();
    _controller.forward(from: 0);
  }
  @override
  void dispose() {
    _controller.dispose();
    onClose();
    super.dispose();
    _stopAutoMoveIsolate();
    _detectionTimer?.cancel();
  }
  void moveToNextZone() {
    if (currentZoneIndex < widget.selectedZones.length - 1) {
      final nextZone = widget.selectedZones[currentZoneIndex + 1];

      // Calculate the destination coordinates in the next zone (at the center)
      final destinationX = nextZone.left + nextZone.width / 2;
      final destinationY = nextZone.top + nextZone.height / 2;

      // Move to the next zone
      moveToZone(destinationX, destinationY);

      currentZoneIndex++;
    }
  }

  void moveToZone(double x, double y) {
    _controller.reset();
    setState(() {
      _destinationX = x;
      _destinationY = y;
    });
    _controller.forward(from: 0);
  }
  void setDestinationCoordinates(double x, double y) {
    setState(() {
      _destinationX = x;
      _destinationY = y;
    });

    _controller.reset();
    _controller.forward(from: 0);
  }
  Widget _buildEndPointMarker(Offset point) {
    return Positioned(
      top: point.dy - 15,
      left: point.dx - 15,
      child: Icon(
        Icons.location_on,
        color: Colors.red,
        size: 30,
      ),
    );
  }
  void addReceivedPosition() {
    if (receivedX != 0.0 && receivedY != 0.0) {
      final newZone = Rect.fromPoints(
        Offset(receivedX - 15, receivedY - 15),
        Offset(receivedX + 15, receivedY + 15),
      );

      setState(() {
        selectedZones.add(newZone);
        zoneNames.add("Received Position");
      });

    }
  }
  void simulatePosition() {
    final random = Random();
    Timer.periodic(Duration(seconds: 5), (timer) {
      double simulatedLatitude = (random.nextDouble() * 2 - 1) * 0.1;
      double simulatedLongitude = (random.nextDouble() * 2 - 1) * 0.1;

      currentLatitude += simulatedLatitude;
      currentLongitude += simulatedLongitude;

      double planX = convertToPlanX(currentLongitude);
      double planY = convertToPlanY(currentLatitude);

      sendPositionToMQTT(planX, planY);

      if (isWatching) {
        moveToZone(planX, planY); // Move character to new position
        moveToNextZone(); // Move character to next zone
      }
    });
  }
  Widget _buildReceivedPositionMarker() {
    return Positioned(
      top: _yPosition - 15,
      left: _xPosition - 15,
      child: Icon(
        Icons.location_on,
        color: Colors.red,
        size: 30,
      ),
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

    }

  }
  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Watch Your Deplacement'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 400,
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(widget.selectedImagePath),
                  fit: BoxFit.contain,
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
                        Text('${area.name}: ${_formatTraverseDates(area.name)}'),
                    ],
                  ),
                ),
                if (showPositionMarker && character.x != null && character.y != null) ...[
                  Positioned(
                    top: character.y - 15,
                    left: character.x - 15,
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ],
                if (_xPosition != null && _yPosition != null) ...[
                  Positioned(
                    left: _xPosition,
                    top: _yPosition,
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isMoving = !_isMoving;
                  if (_isMoving) {
                    _startAutoMoveIsolate();
                    printZoneData(zonesData);

                  } else {
                    _stopAutoMoveIsolate();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.blue[700],
              ),
              child: Text(_isMoving ? 'Arrêter' : 'Démarrer'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Numéro de téléphone de la personne âgée
              String phoneNumber = '123456789'; // Remplacez par le numéro de téléphone réel

              // Créez une URL pour l'appel téléphonique
              String telUrl = 'tel:$phoneNumber';

              // Vérifiez si l'appel téléphonique est pris en charge sur le périphérique
              canLaunch(telUrl).then((canLaunch) {
                if (canLaunch) {
                  // Lancez l'appel téléphonique
                  launch(telUrl);
                } else {
                  // L'appel téléphonique n'est pas pris en charge sur ce périphérique
                  // Vous pouvez afficher un message d'erreur ou prendre une autre action
                  // en cas d'échec de l'appel.
                }
              });
            },
           //nsuite si l'appel téléphonique est pris en charge sur le périphérique en utilisant canLaunch. Si c'est le cas, nous lançons l'appel téléphonique en utilisant launch. Si l'appel téléphonique n'est pas pris en charge, vous pouvez gérer cette situation en affichant un message d'erreur ou en prenant une autre action appropriée.






          style: ElevatedButton.styleFrom(
              primary: Colors.red, // Changer la couleur du bouton en rouge (ou autre couleur)
            ),
            child: Text('Alerte'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
            child: Text(
              'Selected areas:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
              child: ListView.builder(
                itemCount: zonesData.length,
                itemBuilder: (context, index) {
                  final area = zonesData[index];
                  return ListTile(
                    title: Text('Zone ${index + 1}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: zonesData.map((area) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${area.name}'),
                            Text('Coordinates: Left:${area.left.toStringAsFixed(2)}, Top:${area.top.toStringAsFixed(2)}, Right:${area.right.toStringAsFixed(2)}, Bottom:${area.bottom.toStringAsFixed(2)}'),
                            //Text('Surface: ${_calculateSurface(area).toStringAsFixed(2)}'),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              )

          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
            child: Text(
              'Position actuelle : Lat: $_xPosition, Long: $_yPosition',
            ),
          ),
        ],
      ),
    );
  }


  double _calculateSurface(Rect zone) {
    return (zone.width * zone.height) / widget.scale;
  }
}
double photoDisplayScale = 1.0;
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
      xPosition = 300.0;
    } else if (xPosition < 0) {
      xPosition = 0.0;
    }

    if (yPosition > 500.0) {
      yPosition = 500.0;
    } else if (yPosition < 0) {
      yPosition =0.0;
    }

    Future.delayed(Duration(milliseconds: 8000)); // Ajoutez un délai pour contrôler la vitesse du mouvement
  }
}
