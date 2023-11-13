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
      home: ImageSelectionScreen(),
    );
  }
}

class ImageSelectionScreen extends StatefulWidget {
  @override
  _ImageSelectionScreenState createState() => _ImageSelectionScreenState();
}

class SurfacesPainter extends CustomPainter {
  final List<Rect> zones;

  SurfacesPainter(this.zones);

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

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Rect> selectedZones = [];

  // Define the zone boundaries (for demonstration purposes)
  final List<Rect> zoneBoundaries = [
    Rect.fromLTWH(0, 0, 100, 100), // Zone 1 boundary
    Rect.fromLTWH(0, 100, 100, 100), // Zone 2 boundary
    Rect.fromLTWH(100, 0, 100, 100), // Zone 3 boundary
    Rect.fromLTWH(100, 100, 100, 100), // Zone 4 boundary
  ];

  String _getTappedZone(double x, double y) {
    // TODO: Implement the logic to determine the tapped zone based on the x and y coordinates
    // For example, you can check if the tap is inside a zone using the zone boundaries
    // For demonstration purposes, let's assume we have four fixed zones named "zone1", "zone2", "zone3", and "zone4"
    for (int i = 0; i < zoneBoundaries.length; i++) {
      if (zoneBoundaries[i].contains(Offset(x, y))) {
        return 'zone${i + 1}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text('Affichage de données Firestore')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assests/images/plan.png', // Replace with your actual image asset path
            fit: BoxFit.contain, // Keeps the original image size and centers it within the container
          ),
          CustomPaint(
            painter: SurfacesPainter(selectedZones),
          ),
          GestureDetector(
            onTapDown: (TapDownDetails details) {
              // Get the position of the tap relative to the image size
              double x = details.localPosition.dx;
              double y = details.localPosition.dy;

              // Determine the tapped zone based on the coordinates
              String selectedZone = _getTappedZone(x, y);
              print('$x ');

              // Display information for the selected zone
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Selected Zone: $selectedZones'),
              ));
            },
          ),
          ...selectedZones.asMap().entries.map((entry) {
            final index = entry.key;
            final zone = entry.value;
            final zoneName = 'zone${index + 1}';
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
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  double _calculateSurface(Rect zone) {
    // TODO: Implement the calculation for the zone surface based on the zone boundaries
    // For demonstration purposes, let's return a fixed value of 500.0.
    return 500.0;
  }
}
