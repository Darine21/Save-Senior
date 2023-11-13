import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
class SurfaceMeasurementApp extends StatefulWidget {
  @override
  _SurfaceMeasurementAppState createState() => _SurfaceMeasurementAppState();
}
class SurfaceData {
  String id =''; // Identifiant unique de la surface (peut être généré automatiquement par Firebase)
  double surface; // Surface en cm²
  List<double> Point_sup_g; // Coordonnées du point de départ [x, y]
  List<double> Point_sup_d;// Coordonnées du point d'arrivée [x, y]
  List<double> Point_inf_d;
  List<double> Point_inf_g;
  String zoneName;

  List<Map<String, dynamic>> composant;
  SurfaceData({
    required this.surface,
    required this.Point_sup_g,
    required this.Point_sup_d,
    required this.Point_inf_d,
    required this.Point_inf_g,
    required this.zoneName,
    this.composant = const [],
  });// Nom de la zone
}
class SelectedObjectData {
  String objectName; // Nom de l'objet
  double surface; // Surface de l'objet en cm²
  // Ajoutez d'autres propriétés pertinentes pour représenter l'objet sélectionné

  SelectedObjectData({
    required this.objectName,
    required this.surface,
    // Initialisez d'autres propriétés ici si nécessaire
  });
}

class _SurfaceMeasurementAppState extends State<SurfaceMeasurementApp> {
  List<Rect> selectedZones = [];
  List<String> zoneNames = [];
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Map<String, List<SelectedObjectData>> selectedObjectsByZone = {};
  List<SurfaceData> selectedZonesData = [];
  String zone1='';
  String containingZoneName='';
  String zoneName='';

  TextEditingController _zoneNameController = TextEditingController();
  // Variable pour stocker le nom de la zone survolée

  static double scale = 10.0; //echelle : 1mm=10 pixels
  double _calculateSurface(Rect zone) {
    // Implémentez ici le calcul de la surface en fonction des coordonnées de la zone sélectionnée.
    // Par exemple, pour un rectangle, vous pouvez utiliser la formule : longueur x largeur.
    // Notez que cela dépend de la géométrie de la zone que vous souhaitez prendre en charge.
    return zone.width * zone.height;
  }
  void saveIncludedZoneData(String containingZoneName, String includedZoneName, List<SelectedObjectData>? selectedObjects) async {
    if (selectedObjects == null) {
      // If selectedObjects is null, do not perform any further actions.
      return;
    }

    // Access the collection "surfaces"
    CollectionReference surfacesCollection = FirebaseFirestore.instance.collection('surfaces');

    // Check if containingZoneName is not empty before accessing the documents
    if (containingZoneName.isNotEmpty) {
      print ("$containingZoneName");
      // Access the document of the containing zone
      DocumentReference containingZoneDocument = surfacesCollection.doc(containingZoneName);

      // Save the data of the included zone in the "composant" collection of the containing zone
      CollectionReference composantCollection = containingZoneDocument.collection('composant');

      // Generate a unique ID for the included zone's data
      String includedZoneDataId = composantCollection.doc().id;

      // Save the data of the included zone with the generated ID
      await composantCollection.doc(includedZoneDataId).set({
        'zoneName': includedZoneName,
        'selectedObjects': selectedObjects.map((objectData) {
          return {
            'objectName': objectData.objectName,
            'surface': objectData.surface,
            // Add other fields and values here if necessary
          };
        }).toList(),
      });

      print("Included zone data saved successfully in the 'composant' collection.");
    } else {
      print("Error: containingZoneName is empty.");
    }
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
    // Définir une distance minimale pour considérer qu'une nouvelle zone est créée
    final double minDistance = 20;
    for (var zone in selectedZones) {
      double distance = (point - zone.center).distance;
      if (distance < minDistance) {
        return false;
      }
    }
    return true;
  }

  void _selectObjectInZone(String zoneName, String otherZoneName) {
    if (selectedObjectsByZone.containsKey(zoneName)) {
      selectedObjectsByZone[zoneName]!.add(SelectedObjectData(
        objectName: otherZoneName,
        surface: 0, // Replace the value with the actual surface value if needed
      ));
    } else {
      selectedObjectsByZone[zoneName] = [
        SelectedObjectData(
          objectName: otherZoneName,
          surface: 0, // Replace the value with the actual surface value if needed
        ),
      ];
    }

    // Check if otherZone is included in zone
    if (selectedObjectsByZone.containsKey(otherZoneName)) {
      selectedObjectsByZone[otherZoneName]!.add(SelectedObjectData(
        objectName: zoneName,
        surface: 0, // Replace the value with the actual surface value if needed
      ));
    } else {
      selectedObjectsByZone[otherZoneName] = [
        SelectedObjectData(
          objectName: zoneName,
          surface: 0, // Replace the value with the actual surface value if needed
        ),
      ];
    }
  }




  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Mettez à jour le deuxième point de la zone sélectionnée à chaque déplacement du doigt.
      if (selectedZones.isNotEmpty) {
        final endPoint = details.localPosition;
        selectedZones.last = Rect.fromPoints(selectedZones.last.topLeft, endPoint);
      }
    });
  }
  void enregistrerDansFirebase(List<SelectedObjectData>? selectedObjects, String zoneName, String zone1) {
    if (selectedObjects == null) {
      // If selectedObjects is null, do not perform any further actions.
      return;
    }

    // Accédez à la collection "surfaces"
    CollectionReference surfacesCollection = FirebaseFirestore.instance.collection('surfaces');
    print("zoneName: $zoneName");
    print("zone1: $zone1");
    // Vérifiez que zoneName et zone1 ne sont pas vides avant d'accéder aux documents
    if (zoneName.isNotEmpty && zone1.isNotEmpty) {
      // Accédez au document de la zone qui inclut l'autre zone
      DocumentReference zoneDocument = surfacesCollection.doc(zoneName);
      print('zzzzz:$zoneName');
      // Enregistrez les données de la zone incluse dans la collection "composant" du document de la zone incluant
      for (SelectedObjectData objectData in selectedObjects) {
        CollectionReference composantCollection = zoneDocument.collection('composant');
        composantCollection.doc(zoneName).set({
          'objectName': objectData.objectName,
          'surface': objectData.surface,
          // Ajoutez d'autres champs et valeurs ici si nécessaire
        }).then((_) {
          print("Données enregistrées avec succès dans la collection 'composant'.");
        }).catchError((error) {
          print("Erreur lors de l'enregistrement des données : $error");
        });
      }
    } else {
      print("Erreur : zoneName ou zone1 est vide.");
    }
  }






  void _saveSurfaceData(SurfaceData surfaceData) async {
    // Accédez à l'instance de Firestore
    final firestore = FirebaseFirestore.instance;

    // Ajoutez les données de surface dans une collection "surfaces"
    await firestore.collection('surfaces').doc(surfaceData.zoneName).set({
      'surface': surfaceData.surface,
      'Point_sup_g': surfaceData.Point_sup_g,
      'Point_sup_d': surfaceData.Point_sup_d,
      'Point_inf_d': surfaceData.Point_inf_d,
      'Point_inf_g': surfaceData.Point_inf_g,
      'included_zones': _convertIncludedZonesToMap(surfaceData.composant),

    });

    print('Données de surface enregistrées avec succès dans Firebase.');
  }
  Map<String, dynamic> _convertIncludedZonesToMap(List<Map<String, dynamic>> composant) {
    Map<String, dynamic> includedZonesMap = {};
    for (var entry in composant.asMap().entries) {
      includedZonesMap['zone${entry.key}'] = entry.value;
    }
    return includedZonesMap;
  }
  String? _getContainingZone(String zoneName, Rect currentZone) {
    // Parcourez les zones précédemment sélectionnées pour vérifier si la zone actuelle est incluse dans l'une d'entre elles.
    for (int i = 0; i < selectedZones.length; i++) {
      Rect zone = selectedZones[i];
      if (zone.left <= currentZone.left &&
          zone.top <= currentZone.top &&
          zone.right >= currentZone.right &&
          zone.bottom >= currentZone.bottom) {
        // La zone actuelle est incluse dans une zone précédemment sélectionnée
        // Retournez le nom de la zone qui la contient
        return zoneNames[i];
      }
    }
    // Si la boucle se termine sans retourner, la zone actuelle n'est pas incluse dans une zone précédemment sélectionnée
    return null;
  }


  void _onPanEnd(DragEndDetails details) async {
    List<String> namesList = [];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enregistrer la zone'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _zoneNameController,
                  decoration: InputDecoration(
                    labelText: 'Nom de la zone',
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
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Enregistrer'),
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  String zoneName = _zoneNameController.text;
                  print("$containingZoneName");
                  namesList.add(zoneName);

                  // ... Existing code ...

                  // Save the included zone's data in the containing zone's document
                  if (containingZoneName != null) {
                    saveIncludedZoneData(containingZoneName, zoneName, selectedObjectsByZone[zoneName]);
                  }

                  // ... Existing code ...

                  SurfaceData surfaceData = SurfaceData(
                    surface: _calculateSurface(selectedZones.last) * scale * scale,
                    Point_sup_g: [selectedZones.last.left / scale, selectedZones.last.top / scale],
                    Point_inf_d: [selectedZones.last.right / scale, selectedZones.last.bottom / scale],
                    Point_sup_d: [selectedZones.last.right / scale, selectedZones.last.top / scale],
                    Point_inf_g: [selectedZones.last.left / scale, selectedZones.last.bottom / scale],
                    zoneName: zoneName,
                  );

                  _saveSurfaceData(surfaceData);
                  if (zoneNames.isNotEmpty) {
                    zoneNames[zoneNames.length - 1] = zoneName;
                  }
                  print('NameZone: ${zoneName}');
                  _zoneNameController.clear();
                  // Close the dialog
                  Navigator.of(context).pop();

                  // Redessinez la surface pour afficher le nom mis à jour à côté de la zone
                  setState(() {});
                  print('Noms entrés : $namesList');

                }
              },
            ),
          ],
        );
      },
    );

    // Le reste de votre code pour le traitement des zones sélectionnées...
    for (int i = 0; i < selectedZones.length; i++) {
      Rect zone = selectedZones[i];
      String name = zoneNames[i];
      String? containingZoneName; // Variable pour stocker le nom de la zone englobante

      // Calculate the surface in the real measurement unit (e.g., cm²)
      double surface = _calculateSurface(zone) * scale * scale;

      // Print the coordinates of the points to the console
      print('Point supérieur gauche: (${zone.left / scale}, ${zone.top / scale})');
      print('Point supérieur droit: (${zone.right / scale}, ${zone.top / scale})');
      print('Point inférieur gauche: (${zone.left / scale}, ${zone.bottom / scale})');
      print('Point inférieur droit: (${zone.right / scale}, ${zone.bottom / scale})');
      // Print the surface
      print('Surface: ${surface.toStringAsFixed(2)} cm²');
      if (selectedZones.length >= 2) {
        for (int j = 0; j < selectedZones.length; j++) {
          if (i == j) continue; // Ignore the same zone

          Rect otherZone = selectedZones[j];
          String otherZoneName = zoneNames[j];

          if (zone.left <= otherZone.left &&
              zone.top <= otherZone.top &&
              zone.right >= otherZone.right &&
              zone.bottom >= otherZone.bottom) {
            // Zone actuelle (otherZone) est incluse dans la zone (zone) actuelle
            print("Zone incluse trouvée : $otherZoneName");



          // Compare the coordinates to determine if the second zone is inside the first zone

            print("zoneNames before: $zoneNames");
            // If the second zone is inside the first zone, update the selectedObjectsByZone
            // to add the second zone to the list of objects selected in the first zone.
            //String otherZoneName = zoneNames[j];
            print('$otherZoneName');
            _selectObjectInZone(name, otherZoneName);
            print("$otherZoneName");

            // Add the included zone to Firebase
            enregistrerDansFirebase(selectedObjectsByZone[otherZoneName], name, otherZoneName);
            print("zoneNames after: $zoneNames");

            // Remove the included zone from selectedObjectsByZone
            selectedObjectsByZone.remove(otherZoneName);

            print('entre');
          }
        }
        for (int i = 0; i < selectedZones.length; i++) {
          Rect zone = selectedZones[i];
          String zoneName = zoneNames[i];

          enregistrerDansFirebase(selectedObjectsByZone[zoneName], zoneName, zoneName);
        }
      }
    }
  }






  Widget _buildEndPointMarker(Offset point) {
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

        ),
      ),
    );
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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Surface Measurement')),
        body: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            children: [
              Image.asset('assests/images/plan.png'),
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
              ...selectedZones.expand((zone) {
                return [
                  _buildEndPointMarker(zone.topLeft),
                  _buildEndPointMarker(zone.topRight),
                  _buildEndPointMarker(zone.bottomLeft),
                  _buildEndPointMarker(zone.bottomRight),
                ];
              }).toList(),
            ],
          ),
        ),
      ),
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





void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate();

  try {
    runApp(MaterialApp(
      home: SurfaceMeasurementApp(),
    ));
  } catch (e) {
    print("Error handling hardware keyboard event: $e");
  }

}