import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'authentification.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final _signUpKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  Future<void> _showSignUpSuccessDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Inscription réussie'),
          content: const Text('Votre inscription a été effectuée avec succès!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
                // Vous pouvez effectuer d'autres actions ici si nécessaire
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  Future<void> signUp() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      print('SIGN UP SUCCESSFUL!');
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Authentication()),
      );
      _showSignUpSuccessDialog(context);
    } on FirebaseAuthException catch (e) {
      print('Failed to sign in: $e');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Sign In Failed'),
            content: Text(e.message ?? ''),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: Colors.blue[700],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Form(
              key: _signUpKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Image.asset(
                      'assests/images/sign_up.png',
                      width: 400,
                      height: 400,
                    ),
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      controller: _email,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'This field is required!';
                        }
                        return null;
                      },
                      onSaved: (value) {},
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'ex.example@gmail.com',
                        labelText: 'Email',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextFormField(
                      obscureText: true,
                      controller: _password,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'This field is required!';
                        }
                        return null;
                      },
                      onSaved: (value) {},
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Password',
                        labelText: 'Password',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextFormField(
                      obscureText: true,
                      controller: _confirmPassword,
                      validator: (value) {
                        if (value != _password.text) {
                          return 'Passwords do not match!';
                        }
                        return null;
                      },
                      onSaved: (value) {},
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Confirm Password',
                        labelText: 'Confirm Password',
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 75,
                    width: double.infinity,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Colors.blue[700],
                          alignment: Alignment.center,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: signUp,
                        child: const Text(
                          'SIGN UP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
