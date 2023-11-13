import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
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
  // Méthode pour enregistrer la collection "ali" dans le document "noms"
  void enregistrerDansFirebase() {
    // Accédez à la collection "users"
    CollectionReference usersCollection =
    FirebaseFirestore.instance.collection('users');

    // Accédez au document "noms" dans la collection "users"
    DocumentReference nomsDocument = usersCollection.doc('noms');

    // Enregistrez la collection "ali" dans le document "noms"
    nomsDocument.collection('ahmed').add({
      'champ1': 'valeur1',
      'champ2': 'valeur2',
      // Ajoutez d'autres champs et valeurs ici
    }).then((_) {
      print("Données enregistrées avec succès dans la collection 'ali'.");
    }).catchError((error) {
      print("Erreur lors de l'enregistrement des données : $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enregistrer dans Firebase'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: enregistrerDansFirebase,
          child: Text('Enregistrer dans Firebase'),
        ),
      ),
    );
  }
}
