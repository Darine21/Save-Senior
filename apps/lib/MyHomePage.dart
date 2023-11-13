import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentification.dart';
import'connexion.dart';
MqttServerClient? client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
Future<void> connect() async {
  if (client != null && client!.connectionStatus!.state == MqttConnectionState.connected) {
    print('Client is already connected');
    return;
  }


  client = MqttServerClient('broker.emqx.io', 'flutter_client');
  client!.port = 1883;
  client!.logging(on: true);
  client!.onConnected = onConnected;
  client!.onDisconnected = onDisconnected;
  client!.onUnsubscribed = onUnsubscribed;
  client!.onSubscribed = onSubscribeSuccess;
  client!.onSubscribeFail = onSubscribeFail;
  client!.pongCallback = pong;

  final connMessage = MqttConnectMessage()
      .authenticateAs('username', 'password')
      .keepAliveFor(60)
      .withWillTopic('willtopic')
      .withWillMessage('Will message')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);
  client!.connectionMessage = connMessage;

  try {
    await client!.connect();
    print('Connected');
    final builder = MqttClientPayloadBuilder();
    builder.addString('Hello, MQTT!');
    print('cccc');
    client!.publishMessage('topic1', MqttQos.atMostOnce, builder.payload!);
    onConnected(); // Appeler la méthode onConnected ici
  } catch (e) {
    print('Exception: $e');
    client!.disconnect();
    throw e;
  }


  client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
    final MqttPublishMessage? message = c[0].payload as MqttPublishMessage?;
    if (message != null) {
      final payload =
      MqttPublishPayload.bytesToStringAsString(message.payload.message);

      print('Received message: $payload from topic: ${c[0].topic}>');
    }
  });
}

void disconnect() {
  if (client != null && client!.connectionStatus!.state == MqttConnectionState.connected) {
    client!.disconnect();
  }
}

void onConnected() {
  print('Connected');
  if (client != null && client!.connectionStatus!.state == MqttConnectionState.connected) {
    final builder = MqttClientPayloadBuilder();
    builder.addString('Hello mr/Mme');
    client!.publishMessage('topic1', MqttQos.atMostOnce, builder.payload!);
    client!.subscribe('topic1', MqttQos.atMostOnce);
  } else {
    print('MQTT client is null or not connected');
  }
}


void onDisconnected() {
  print('Disconnected');
  client = null; // Réinitialiser le client MQTT après la déconnexion
}

void onSubscribeSuccess(String? topic) {
  print('Subscribed to topic: $topic');
}

void onSubscribeFail(String topic) {
  print('Failed to subscribe to topic: $topic');
}

void onUnsubscribed(String? topic) {
  print('Unsubscribed from topic: $topic');
}

void pong() {
  print('Ping response received');
}
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

        home: const MyHomePage(title: 'Home Page'),

    );
  }
}



class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class LoginPageRoute extends MaterialPageRoute {
  LoginPageRoute() : super(builder: (BuildContext context) => Authentication());
}
class ConnexionPageRoute extends MaterialPageRoute{
  ConnexionPageRoute() : super(builder: (BuildContext context) => MyHomeePage(title: 'connexion'));
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    //_addMessage('Connected');
  }

  void _addMessage(String message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  Future<void> _addData(String task) async {
    CollectionReference tasks = FirebaseFirestore.instance.collection('tasks');
    return tasks
        .add({'task': task, 'number': 10})
        .then((value) => print('New task added'))
        .catchError((error) => print('Failed to add Task'));
  }

  Future<void> _deleteData(String id) async {
    CollectionReference tasks = FirebaseFirestore.instance.collection('tasks');
    return tasks
        .doc(id)
        .delete()
        .then((value) => print('Data has been deleted'))
        .catchError((error) => print('Failed to delete data'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightGreen[700],
        title: Text(widget.title),
      ),
      body:
      SingleChildScrollView(

        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Image.asset(
                'assests/images/imagee.jpg'),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Text(message),
                );
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, LoginPageRoute());
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.lightGreen[700],
                minimumSize: Size(300, 35), // Changer la dimension du bouton ici
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),// Changer la couleur du bouton ici
              ),
              child: Text('Connected', style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              )
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, ConnexionPageRoute());
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.lightGreen[700],
                minimumSize: Size(300, 35), // Changer la dimension du bouton ici
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10), // Changer la couleur du bouton ici

              ),
              child:Text('topic',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              )
              ),
            ),
          ],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

    );
  }
}

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login Page'),
        backgroundColor: Colors.lightGreen[700],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [


          ],
        ),
      ),
    );
  }
}

