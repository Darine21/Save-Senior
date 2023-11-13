import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? function;

  const MyButton({required this.child, this.function});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: function, // Ajout de la fonction onTap
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.all(10),
          color: Colors.brown[300],
          child: child,
        ),
      ),
    );
  }
}
