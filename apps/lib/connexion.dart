import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

MqttServerClient? client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
  await connect();
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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomeePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomeePage extends StatefulWidget {
  const MyHomeePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomeePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomeePage> {
  int _counter = 0;
  List<String> _messages = [];

  void _addMessage(String message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  @override
  void initState() {
    super.initState();
    _addMessage('Connected');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final message = _messages[index];
            return ListTile(
              title: Text(message),
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              onConnected();
            },
            icon: const Icon(Icons.app_registration_sharp),
            label: const Text(
              'Connect',
              style: TextStyle(fontSize: 20),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              disconnect();
            },
            icon: const Icon(Icons.app_registration_sharp),
            label: const Text(
              'Disconnect',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}
