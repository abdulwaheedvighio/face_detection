import 'package:flutter/material.dart';
import 'face_screen.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Employee Login")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FaceScreen(
                  userName: "",
                  isRegister: false,
                ),
              ),
            );
          },
          child: Text("Login with Face"),
        ),
      ),
    );
  }
}