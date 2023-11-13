import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:typed_data/typed_buffers.dart'; // Ajoutez cette ligne pour résoudre l'erreur "typed.Uint8Buffer"
import 'package:path/path.dart' as path;
import 'sss.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';

import 'package:mqtt_client/mqtt_server_client.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Title',
      home: const Home(),
    );
  }
}
class SurfacePainter extends CustomPainter {
  final List<Rect> zones;

  SurfacePainter(this.zones);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var zone in zones) {
      canvas.drawRect(zone, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
class SurfaceData {
  double surface; // Surface en cm²
  List<double> pointSupG; // Coordonnées du point de départ [x, y]
  List<double> pointSupD; // Coordonnées du point d'arrivée [x, y]
  List<double> pointInfD;
  List<double> pointInfG;
  String zoneName;
  List<SurfaceData>? includedZones;

  SurfaceData({
    required this.surface,
    required this.pointSupG,
    required this.pointSupD,
    required this.pointInfD,
    required this.pointInfG,
    required this.zoneName,
    this.includedZones,
  });
}
class Home extends StatefulWidget {
  final VoidCallback? login;
  final String? selectedImagePath;
  final String? nom;
  final String? prenom;

  const Home({Key? key,this.login, this.selectedImagePath, this.nom, this.prenom}) : super(key: key);


  @override
  _HomeState createState() => _HomeState();
}
class DeplacementPageRoute extends MaterialPageRoute {
  final String selectedImagePath;
  final List<Rect> selectedZones;
  final List<String> zoneNames;
  final double scale; // Ajoutez cette ligne

  DeplacementPageRoute({
    required this.selectedImagePath,
    required this.selectedZones,
    required this.zoneNames,
    required this.scale, // Ajoutez cette ligne
  }) : super(
    builder: (BuildContext context) => PhotoDisplayPage(
      selectedImagePath: selectedImagePath,
      selectedZones: selectedZones,
      zoneNames: zoneNames,
      scale: scale, // Ajoutez cette ligne
    ),
  );
}




class _HomeState extends State<Home> {
  //List<RoomMarker> markers = [];
  GlobalKey _imageKey = GlobalKey();

  //RoomMarker? selectedMarker;
  TextEditingController nameController = TextEditingController();
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedImageName = ''; // Nom de l'image sélectionnée
  File? selectedImageFile;
  String selectedImagePath = ''; // Fichier de l'image sélectionnée
  List<Rect> selectedZones =[];
  List<String> zoneNames = [];
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController _zoneNameController = TextEditingController();
  List<List<double>> includedZoneCoordinates = [];
  String _nom = ''; // Ajoutez cette ligne
  String _prenom = ''; // Ajoutez cette ligne
  static double scale = 10.0; // Echelle : 1mm=10 pixels
  ImageProvider? imageProvider; // Ajoutez cette ligne
  MqttClient? client; // Déclarez une instance de MqttClient
  StreamSubscription? mqttListen;
  // Initialize with the desired scale


  // Fonction pour calculer la surface d'une zone
  double _calculateSurface(Rect zone) {
    return zone.width * zone.height;
  }

  void _onPanStart(DragStartDetails details) {
    if (details.localPosition != null) {
      final startPoint = details.localPosition!;
      // Vérifier si la nouvelle zone est suffisamment éloignée des zones existantes
      if (_isNewZone(startPoint)) {
        setState(() {
          final newZone = Rect.fromPoints(startPoint, startPoint);
          selectedZones.add(newZone);
          zoneNames.add("");
        });
      }
    }
  }


  bool _isNewZone(Offset point) {
    final double minDistance = 20;
    for (var zone in selectedZones) {
      double distance = (point - zone.center).distance;
      if (distance < minDistance) {
        return false;
      }
    }
    return true;
  }

  bool _isZoneIncluded(Rect zoneToCheck, Rect zoneToCompare) {
    return zoneToCompare.contains(zoneToCheck.topLeft) &&
        zoneToCompare.contains(zoneToCheck.topRight) &&
        zoneToCompare.contains(zoneToCheck.bottomLeft) &&
        zoneToCompare.contains(zoneToCheck.bottomRight);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (selectedZones.isNotEmpty) {
        final endPoint = details.localPosition;
        selectedZones.last = Rect.fromPoints(selectedZones.last.topLeft, endPoint);
      }
    });
  }


  void _onPanEnd(DragEndDetails details) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Save a zone'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _zoneNameController,
                  decoration: InputDecoration(
                    labelText: 'Name a zone',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Veuillez entrer un nom pour la zone';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  String zoneName = _zoneNameController.text;

                  SurfaceData surfaceData = SurfaceData(
                    surface: _calculateSurface(selectedZones.last) * scale * scale,
                    pointSupG: [selectedZones.last.left / scale, selectedZones.last.top / scale],
                    pointInfD: [selectedZones.last.right / scale, selectedZones.last.bottom / scale],
                    pointSupD: [selectedZones.last.right / scale, selectedZones.last.top / scale],
                    pointInfG: [selectedZones.last.left / scale, selectedZones.last.bottom / scale],
                    zoneName: zoneName,
                  );
                  if (selectedZones.isNotEmpty) {
                    // Récupérer le nom de la zone incluse (dernière zone dans la liste selectedZones)
                    String includedZoneName = zoneNames.last; // Vous devez définir zoneNames quelque part dans votre code

                    // Modifier documentPath pour récupérer le nom de la zone incluse
                    String documentPath = includedZoneName;
                    print("rrrf:$documentPath"); // Affiche le nom de la zone incluse


                    _saveSurfaceData(surfaceData);

                    if (zoneNames.isNotEmpty) {
                      zoneNames[zoneNames.length - 1] = zoneName;
                    }

                    _zoneNameController.clear();
                    Navigator.of(context).pop();
                    setState(() {});

                    if (zoneNames.isNotEmpty) {
                      List<double> currentZoneCoordinates = [
                        selectedZones.last.left / scale,
                        selectedZones.last.top / scale,
                        selectedZones.last.right / scale,
                        selectedZones.last.bottom / scale,
                      ];

                      List<List<double>> includedCoordinates = [];
                      List<String> includedZoneNames = [];

                      for (int i = 0; i < selectedZones.length - 1; i++) {
                        if (_isZoneIncluded(selectedZones.last, selectedZones[i])) {
                          includedCoordinates.add([
                            selectedZones[i].left / scale,
                            selectedZones[i].top / scale,
                            selectedZones[i].right / scale,
                            selectedZones[i].bottom / scale,
                          ]);
                          includedZoneNames.add(zoneNames[i]);
                        }
                      }

                      if (includedCoordinates.isNotEmpty) {
                        includedZoneCoordinates.add(currentZoneCoordinates);
                        includedZoneCoordinates.addAll(includedCoordinates);

                        SurfaceData surfaceData = SurfaceData(
                          surface: _calculateSurface(selectedZones.last) * scale * scale,
                          pointSupG: [selectedZones.last.left / scale, selectedZones.last
                              .top / scale
                          ],
                          pointInfD: [selectedZones.last.right / scale, selectedZones.last
                              .bottom / scale
                          ],
                          pointSupD: [selectedZones.last.right / scale, selectedZones.last
                              .top / scale
                          ],
                          pointInfG: [selectedZones.last.left / scale, selectedZones.last
                              .bottom / scale
                          ],
                          zoneName: zoneName,
                          includedZones: [],
                        );

                        // Vérifier si la zone est incluse dans la zone supérieure
                        bool isIncludedInMainZone = false;
                        for (int i = 0; i < selectedZones.length - 1; i++) {
                          if (_isZoneIncluded(selectedZones.last, selectedZones[i])) {
                            isIncludedInMainZone = true;
                            break;
                          }
                        }
                        for (int i = 0; i < includedCoordinates.length; i++) {
                          // Inverser les noms de zone
                          String zoneName = includedZoneNames[i]; // Nom de la zone supérieure
                          String includedZoneName = zoneNames
                              .last; // Nom de la zone incluse
                          print('Zone $includedZoneName is included in Zone $zoneName');
                        }

                        // Enregistrer les données dans Firestore
                        if (isIncludedInMainZone) {
                          _saveSurfaceData(
                              surfaceData, includedZoneNames, includedZoneCoordinates);
                        } else {
                          _saveSurfaceData(surfaceData);
                        }
                      }
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
  void printIncludedZoneCoordinates(List<String> includedZoneNames, List<List<double>> includedCoordinates) {
    for (int i = 0; i < includedZoneNames.length; i++) {
      String zoneName = includedZoneNames[i];
      List<double> coordinates = includedCoordinates[i];
      print('Zone $zoneName coordinates: [left: ${coordinates[0]}, top: ${coordinates[1]}, right: ${coordinates[2]}, bottom: ${coordinates[3]}]');
    }
  }
  void _saveSurfaceData(SurfaceData surfaceData, [List<String>? includedZoneNames, List<List<double>>? includedZoneCoordinates]) async {
    CollectionReference surfacesCollection = FirebaseFirestore.instance.collection('house');
    String documentPath = surfaceData.zoneName;
    print("rrdr:$documentPath");


    // If there are included zones, save the data in the "included_zones" subcollection
    if (includedZoneNames != null && includedZoneNames.isNotEmpty &&
        includedZoneCoordinates != null && includedZoneCoordinates.isNotEmpty) {
      for (int i = 0; i < includedZoneNames.length; i++) {
        String includedZoneName = includedZoneNames[i];
        print("name:$includedZoneName");
        if (documentPath.isNotEmpty) {
          DocumentReference documentReference = surfacesCollection.doc(includedZoneName);
          await documentReference.set({
            'surface': surfaceData.surface,
            'pointSupG': surfaceData.pointSupG,
            'pointSupD': surfaceData.pointSupD,
            'pointInfD': surfaceData.pointInfD,
            'pointInfG': surfaceData.pointInfG,
          });

          Map<String, dynamic> includedZoneData = {
            'surface': surfaceData.surface,
            'pointSupG': includedZoneCoordinates[i][0],
            'pointSupD': includedZoneCoordinates[i][2],
            'pointInfD': includedZoneCoordinates[i][3],
            'pointInfG': includedZoneCoordinates[i][1],
          };

          await documentReference.collection('included_zones').doc(surfaceData.zoneName).set(includedZoneData);
        }
      }
    }
  }



@override
void initState() {
  super.initState();
  //initMqtt(); // Appel de la méthode statique initMqtt de la classe MqttService
  //trackUserPosition();
}

@override
void dispose() {
  nameController.dispose();
  //onClose(); // Appel de la méthode statique onClose de la classe MqttService
  super.dispose();
}




  Widget _buildZoneMarker(Offset point) {
    return Positioned(
      top: point.dy - 15,
      left: point.dx - 15,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          //color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'Zone ${selectedZones.length}',
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ),
    );
  }





  void getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        selectedImageFile = File(pickedImage.path);
        selectedImagePath = pickedImage.path;
        selectedImageName = path.basename(selectedImagePath);
        //addReceivedPosition();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //print('Nom reçu: ${widget.nom}');
    //print('Prénom reçu: ${widget.prenom}');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
          CircleAvatar(
          radius: 20,
          backgroundImage: widget.selectedImagePath != null && widget.selectedImagePath!.isNotEmpty
              ? Image.file(File(widget.selectedImagePath!)).image
              : AssetImage('assests/images/defaultavatar.jpg'),
        ),
            SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, MR/Mme ${widget.prenom} ${widget.nom}',
                  style: TextStyle(fontSize: 15),
                ),

                Center(
                  child: Text(
                    'House Plan',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              ],
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: Container(
        // Wrap the Column with Expanded to set height
        // Set a fixed height that fits within the parent constraints
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Stack(
                  children: [
                    if (selectedImageFile != null) // Check if selectedImageFile is not null
                      Image.file(
                        selectedImageFile!,
                        width: 400,
                        height: 400,
                        fit: BoxFit.contain,
                      ),
                    CustomPaint(
                      painter: SurfacePainter(selectedZones),
                    ),

                  ...selectedZones.asMap().entries.map((entry) {
                    final index = entry.key;
                    final zone = entry.value;
                    final zoneName = zoneNames[index];
                    return Positioned(
                      top: zone.top,
                      left: zone.left,
                      width: zone.width,
                      height: zone.height,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2.0),
                        ),

                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Surface: ${_calculateSurface(zone).toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Text(
                                zoneName,
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),

                          ],
                        ),
                      ),
                    );
                  }).toList(),

                ],
              ),
            ),
        ),// ... Other widgets ...
        ],

      ),
      ),

      floatingActionButton: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Set to min to take only required height
            children: [
              ElevatedButton(
                onPressed: () => getImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue[700],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image_outlined),
                    SizedBox(width: 8),
                    Text('Pick from Gallery'),
                  ],
                ),
              ),



              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => getImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue[700],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera),
                    SizedBox(width: 8),
                    Text('Pick from Camera'),
                  ],
                ),
              ),



              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    DeplacementPageRoute(
                      selectedImagePath: selectedImagePath,
                      selectedZones: selectedZones,
                      zoneNames: zoneNames,
                      scale: photoDisplayScale,
                    ),
                  );

                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue[700],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.visibility),
                    SizedBox(width: 8),
                    Text('Watch your deplacement'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



}
