import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import "dart:io";
import 'package:image_picker/image_picker.dart';
import "plan.dart";
import "package:flutter/services.dart";
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formulaire Personne Agée',

      home: MyForm(),
    );
  }
}

class MyForm extends StatefulWidget {
  @override
  _MyFormState createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _nom = '';
  String _prenom = '';
  int _age = 0;
  String _situationSociale = 'Single'; // Valeur par défaut
  String _genre = 'Man'; // Valeur par défaut
  int _personneDansLaMaison = 0;

  ImageProvider? imageProvider; // Ajoutez cette ligne
  String selectedImagePath = '';
  final List<String> _situationsSociales = ['Single', 'Bride', 'Divorce'];
  final List<String> _genres = ['Man', 'Women'];
  XFile? _image;
  TextEditingController _nomController = TextEditingController();
  TextEditingController _prenomController = TextEditingController();


  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      _image = pickedImage;
    });
  }
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Enregistrer les données dans Firestore
      await FirebaseFirestore.instance.collection('personne_agee').doc(_nom).set({
        'nom': _nom,
        'prenom': _prenom,
        'age': _age,
        'situationSociale': _situationSociale,
        'genre': _genre,
        'numeroTelephone': _personneDansLaMaison,
      });

      // Mettre à jour les valeurs du contrôleur (pour la réinitialisation)
      _nomController.text = _nom;
      _prenomController.text = _prenom;
    print ("le nom : $_nom");
      print ("le nom : $_prenom");
      // Mettre à jour l'image
      setState(() {
        imageProvider = _image != null ? FileImage(File(_image!.path)) : null;
      });

      // Effacer les champs après l'enregistrement


      // Naviguer vers la page suivante
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Home(
            selectedImagePath: _image != null ? _image!.path : '',
            nom: _nom,
            prenom: _prenom,
          ),
        ),
      );

      print("enregistrement dans firebase ");

    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Elderly person form'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
    child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'FirstName'),
                onSaved: (value) => _nom = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Name'),
                onSaved: (value) => _prenom = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un prénom';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSaved: (value) => _age = int.parse(value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un âge';
                  }
                  return null;
                },
              ),

              TextFormField(
                decoration: InputDecoration(labelText: 'PhoneNumber'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSaved: (value) => _age = int.parse(value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le numero de tele';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _situationSociale,
                items: _situationsSociales.map((String situation) {
                  return DropdownMenuItem<String>(
                    value: situation,
                    child: Text(situation),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _situationSociale = newValue!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Social situation',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez choisir une situation sociale';
                  }
                  return null;
                },
              ),

              DropdownButtonFormField<String>(
                value: _genre,
                items: _genres.map((String genre) {
                  return DropdownMenuItem<String>(
                    value: genre,
                    child: Text(genre),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _genre = newValue!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Gender',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez choisir un genre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue[400],),
                child: Text('Upload a photo'),

              ),
              _image != null
                  ? Image.file(
                File(_image!.path),
                height: 100,
              )
                  : SizedBox.shrink(),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue[700],),
                child: Text('Soumettre'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
