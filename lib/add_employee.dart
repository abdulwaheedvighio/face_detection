import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEmployee extends StatelessWidget {
  final TextEditingController nameController = TextEditingController();

  Future<void> addEmployee(String name) async {
    List<double> embedding = List.generate(128, (i) => i * 0.02);

    await FirebaseFirestore.instance.collection('employees').add({
      'name': name,
      'embedding': embedding,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Employee")),
      body: Column(
        children: [
          TextField(controller: nameController),
          ElevatedButton(
            onPressed: () {
              addEmployee(nameController.text);
            },
            child: Text("Add"),
          )
        ],
      ),
    );
  }
}