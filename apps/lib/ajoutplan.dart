import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
      home: const House(),
    );
  }
}

class House extends StatefulWidget {
  final VoidCallback? login;
  const House({Key? key, this.login}) : super(key: key);

  @override
  _HousePlanPageState createState() => _HousePlanPageState();
}

class _HousePlanPageState extends State<House> {
  List<RoomMarker> markers = [];
  GlobalKey _imageKey = GlobalKey();
  RoomMarker? selectedMarker;
  TextEditingController nameController = TextEditingController();
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedImageName = 'plan4'; // Nom de l'image sélectionnée
  String selectedImagePath = ''; // Chemin de l'image sélectionnée

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void deleteSelectedMarker() {
    if (selectedMarker != null) {
      setState(() {
        markers.remove(selectedMarker);
        selectedMarker = null;
      });
    }
  }

  void saveMarkerData(RoomMarker marker, String imageId) {
    firestore
        .collection('plan')
        .doc(selectedImageName) // Utilisez selectedImageName comme ID de document
        .collection('marker')
        .add({
      'name': marker.name,
      'position': {
        'dx': marker.position.dx,
        'dy': marker.position.dy,
      },
    });
  }

  void fetchMarkers(String imageId) {
    firestore
        .collection('plan')
        .doc(selectedImageName) // Utilisez selectedImageName comme ID de document
        .collection('markers')
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((doc) {
        String name = doc.data()['name'];
        double dx = doc.data()['position']['dx'];
        double dy = doc.data()['position']['dy'];
        RoomMarker marker = RoomMarker(
          name: name,
          position: Offset(dx, dy),
        );
        setState(() {
          markers.add(marker);
        });
      });
    });
  }

  void getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        selectedImagePath = pickedImage.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: const Text('House Plan'),
      ),
      body: GestureDetector(
        onTapDown: (details) {
          if (selectedMarker == null) {
            final RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;
            final tapPosition = box.globalToLocal(details.globalPosition);
            setState(() {
              markers.add(
                RoomMarker(
                  name: '',
                  position: tapPosition,
                ),
              );
            });
          }
        },
        child: RepaintBoundary(
          key: _imageKey,
          child: Stack(
            children: [
              if (selectedImagePath.isNotEmpty)
                Image.file(
                  File(selectedImagePath),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                ),
              if (selectedImagePath.isEmpty)
                SvgPicture.asset(
                  'assests/images/$selectedImageName.svg', // Utilisez selectedImageName pour construire le chemin de l'image
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                ),
              ...markers.map((marker) {
                return Positioned(
                  left: marker.position.dx,
                  top: marker.position.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        marker.position += details.delta;
                      });
                    },
                    onTap: () {
                      setState(() {
                        selectedMarker = marker;
                        nameController.text = selectedMarker!.name;
                      });
                      showDialog(
                        context: context,
                        builder: (BuildContext builderContext) {
                          return AlertDialog(
                            title: const Text('Edit Room Name'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Room Name',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedMarker!.name = nameController.text;
                                    saveMarkerData(selectedMarker!, 'image_id');
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('Save'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          marker.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext builderContext) {
              return AlertDialog(
                title: const Text('Add Room'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Room Name',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        final RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;
                        final tapPosition = box.globalToLocal(Offset.zero);
                        markers.add(
                          RoomMarker(
                            name: nameController.text,
                            position: tapPosition,
                          ),
                        );
                        saveMarkerData(markers.last, 'image_id');
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: selectedMarker != null
          ? BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteSelectedMarker,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext builderContext) {
                    return AlertDialog(
                      title: const Text('Edit Room Name'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Room Name',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedMarker!.name = nameController.text;
                              saveMarkerData(selectedMarker!, 'image_id');
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      )
          : null,
    );
  }
}

class RoomMarker {
  String name;
  Offset position;

  RoomMarker({required this.name, required this.position});
}
