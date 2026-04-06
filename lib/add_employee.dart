import 'package:flutter/material.dart';
import 'face_screen.dart';

class AddEmployee extends StatelessWidget {
  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Employee")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Enter Name"),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FaceScreen(
                      userName: nameController.text,
                      isRegister: true,
                    ),
                  ),
                );
              },
              child: Text("Register Face"),
            )
          ],
        ),
      ),
    );
  }
}