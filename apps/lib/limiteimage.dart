import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate();

  runApp(MyApp());
}

class Point {
  double x;
  double y;

  Point(this.x, this.y);
}

class Zone {
  String name;
  List<Point> points;

  Zone({required this.name, required this.points});
}

class PhotoLimiter extends StatefulWidget {
  @override
  _PhotoLimiterState createState() => _PhotoLimiterState();
}

class _PhotoLimiterState extends State<PhotoLimiter> {
  List<List<Point>> _pointsList = []; // Liste pour stocker les points de chaque trait
  List<Point> _currentPoints = [];
  bool _showLine = false;
  String _currentZoneName = ''; // Variable pour stocker le nom de la zone en cours
  String _hoveredZoneName = ''; // Variable pour stocker le nom de la zone survolée
  List<Zone> _zonesList =[];
  void _handleTapDown(TapDownDetails details) {
    setState(() {
      if (!_showLine) {
        // Start drawing a new line segment
        _currentPoints = [Point(details.localPosition.dx, details.localPosition.dy)];
        _showLine = true;
      } else {
        // Continue drawing the current line segment
        _currentPoints.add(Point(details.localPosition.dx, details.localPosition.dy));
      }
    });
  }
  void _handlePanUpdate(DragUpdateDetails details) {
    // Get the current position of the pan update
    final currentPosition = details.localPosition;

    // Check if the current position is inside any zone
    String hoveredZoneName = '';
    for (Zone zone in _zonesList) {
      // Declare variables i and j here
      for (int i = 0, j = zone.points.length - 1; i < zone.points.length; j = i++) {
        double xi = zone.points[i].x;
        double yi = zone.points[i].y;
        double xj = zone.points[j].x;
        double yj = zone.points[j].y;

        bool intersect = ((yi > currentPosition.dy) != (yj > currentPosition.dy)) &&
            (currentPosition.dx < (xj - xi) * (currentPosition.dy - yi) / (yj - yi) + xi);

        if (intersect) {
          hoveredZoneName = zone.name;
          break;
        }
      }
    }

    // Update the hovered zone name
    setState(() {
      _hoveredZoneName = hoveredZoneName;
    });
  }

  void _showPointDetails(double x, double y) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Point Details'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('X: $x, Y: $y'),
              SizedBox(height: 16),
              TextFormField(
                onChanged: (value) {
                  setState(() {
                    _currentZoneName = value; // Update the zone name when the TextFormField value changes
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Zone Name',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Save the points to the list and reset the current points
                _toggleLineVisibility();

                // Call the _saveZoneToFirestore function with the zone name
                _saveZoneToFirestore(_currentZoneName, _currentPoints);

                _currentPoints.clear();
                _currentZoneName = ''; // Reset the zone name
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }


  void _saveZoneToFirestore(String zoneName, List<Point> points) {
    if (zoneName.isNotEmpty && points.isNotEmpty) {
      // Create a list to store the coordinates of the points as Map<String, double>
      List<Map<String, double>> zonePoints = points.map((point) =>
      {
        'x': point.x,
        'y': point.y,
      }).toList();

      // Save the zone to Firebase Firestore
      FirebaseFirestore.instance.collection('zones').doc(zoneName).set({
        'name': zoneName,
        'points': zonePoints,
      }).then((_) {
        print('Zone enregistrée avec succès dans Firestore');
      }).catchError((error) {
        print('Erreur lors de l\'enregistrement de la zone: $error');
      });
    }
  }

  void _toggleLineVisibility() {
    setState(() {
      if (_showLine) {
        // Save the current line segment and reset for the new one
        _pointsList.add(List.from(_currentPoints));
        _saveZoneToFirestore(_currentZoneName, _currentPoints);
        _currentPoints.clear();
        _currentZoneName = ''; // Réinitialiser le nom de la zone
      }
      _showLine = !_showLine;
    });
  }

  void _resetPoints() {
    setState(() {
      _pointsList.clear();
      _currentPoints.clear();
      _showLine = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Limiteur de Photo'),
      ),
      body: GestureDetector(
        onTapDown: _handleTapDown,
        onPanUpdate: _handlePanUpdate, // Add onPanUpdate event

        child: Center(
          child: Stack(
            children: [
              Image.asset(
                'assests/images/plan.png', // Remplacez ceci par le chemin de votre photo
                fit: BoxFit.contain,
              ),
              CustomPaint(
                painter: PointsPainter(pointsList: _pointsList, currentPoints: _currentPoints, showLine: _showLine),
                size: Size.infinite,
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(8),
                  child: Text(
                    _hoveredZoneName, // Display the zone name when hovering over a zone
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_showLine) // Show the button only when drawing a zone
            FloatingActionButton(
              onPressed: () => _showPointDetails(_currentPoints.last.x, _currentPoints.last.y),
              child: Icon(Icons.edit),
            ),
          SizedBox(height: 15),
          FloatingActionButton(
            onPressed: _resetPoints,
            child: Icon(Icons.delete),
          ),
        ],
      ),
    );
  }
}

class PointsPainter extends CustomPainter {
  List<List<Point>> pointsList;
  List<Point> currentPoints;
  bool showLine;

  PointsPainter({required this.pointsList, required this.currentPoints, required this.showLine});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.blue
      ..style = PaintingStyle.stroke;

    // Draw previous line segments
    for (final points in pointsList) {
      final connectedPath = _connectPoints(points);
      final dashedPath = _dashPath(connectedPath);
      canvas.drawPath(dashedPath, linePaint);
    }

    // Draw the current line segment if it is visible
    if (currentPoints.isNotEmpty && showLine) {
      final connectedPath = _connectPoints(currentPoints);
      final dashedPath = _dashPath(connectedPath);
      canvas.drawPath(dashedPath, linePaint);
    }
  }

  Path _connectPoints(List<Point> points) {
    Path path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points.first.x, points.first.y);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }
    }
    return path;
  }

  Path _dashPath(Path sourcePath) {
    final double dashWidth = 8.0;
    final double dashSpace = 8.0;

    final pathMetrics = sourcePath.computeMetrics();
    final dashPath = Path();

    for (ui.PathMetric pathMetric in pathMetrics) {
      var metricLength = 0.0;
      var isDraw = true;

      while (metricLength < pathMetric.length) {
        double distanceToMove = isDraw ? dashWidth : dashSpace;
        if (metricLength + distanceToMove > pathMetric.length) {
          distanceToMove = pathMetric.length - metricLength;
        }

        final extractPath = pathMetric.extractPath(
          metricLength,
          metricLength + distanceToMove,
        );
        dashPath.addPath(extractPath, Offset.zero);
        metricLength += distanceToMove;
        isDraw = !isDraw;
      }
    }

    return dashPath;
  }

  @override
  bool shouldRepaint(PointsPainter oldDelegate) {
    return oldDelegate.currentPoints != currentPoints || oldDelegate.showLine != showLine;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PhotoLimiter(),
    );
  }
}
