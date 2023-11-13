import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'button.dart';
import 'Personne.dart';

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
      home: const InHouse(),
    );
  }
}

class InHouse extends StatefulWidget {
  final VoidCallback? login;
  const InHouse({Key? key, this.login}) : super(key: key);

  @override
  _InHouseState createState() => _InHouseState();
}

class _InHouseState extends State<InHouse> {
  GlobalKey _imageKey = GlobalKey();
  double personneX=0;
  TextEditingController nameController = TextEditingController();
  String selectedImageName = 'plan4'; // Nom de l'image sélectionnée
  String selectedImagePath = ''; // Chemin de l'image sélectionnée

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
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

  void moveRight() {
    setState(() {
      personneX -= 0.02;
    });
  }

  void moveLeft() {
    setState(() {
      personneX += 0.02;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('deplacement Plan'),
        backgroundColor: Colors.lightGreen[700],

      ),
      body: Container(
        decoration: BoxDecoration(
          image: selectedImagePath.isNotEmpty
              ? DecorationImage(
            image: FileImage(File(selectedImagePath)),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    child: AnimatedContainer(
                      alignment: Alignment(0, 0.46),
                      duration: Duration(milliseconds: 0),
                      child: MyPersonne(),
                    ),
                  ),
                  if (selectedImagePath.isEmpty)
                    SvgPicture.asset(
                      'assests/images/$selectedImageName.svg',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MyButton(
                    child: Icon(Icons.arrow_back, size: 40),
                    function: moveLeft,
                  ),
                  MyButton(
                    child: Icon(Icons.arrow_upward, size: 40),

                  ),
                  MyButton(
                    child: Icon(Icons.arrow_forward, size: 40),
                    function: moveRight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
