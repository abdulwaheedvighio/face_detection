import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'login_screen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Attendance App")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: Text("Register Employee"),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RegisterScreen()));
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text("Employee Login"),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}