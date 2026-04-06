import 'package:flutter/material.dart';
import 'face_screen.dart';

class RegisterScreen extends StatelessWidget {
  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register Employee")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Employee Name"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FaceScreen(
                        userName: nameController.text,
                        isRegister: true,
                      ),
                    ),
                  );
                }
              },
              child: Text("Capture Face"),
            ),
          ],
        ),
      ),
    );
  }
}