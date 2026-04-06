import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Recognizer {
  final _db = FirebaseFirestore.instance;

  // 🔥 Better threshold (MobileFaceNet ke liye)
  final double threshold = 0.8;

  /// 🔷 REGISTER (multiple embeddings store karega)
  Future<void> register(
      String name, List<double> embedding, String imageUrl) async {
    try {
      var query = await _db
          .collection('employees')
          .where('name', isEqualTo: name)
          .get();

      if (query.docs.isEmpty) {
        // ✅ New user
        await _db.collection('employees').add({
          'name': name,
          'embeddings': [embedding], // 🔥 LIST
          'image_url': imageUrl,
        });
      } else {
        // ✅ Existing user → embedding add karo
        var docId = query.docs.first.id;

        await _db.collection('employees').doc(docId).update({
          'embeddings': FieldValue.arrayUnion([embedding]),
        });
      }

      print("✅ User Registered/Updated");
    } catch (e) {
      print("❌ Register Error: $e");
    }
  }

  /// 🔷 RECOGNIZE (multiple embeddings compare)
  Future<String?> recognize(List<double> input) async {
    try {
      var data = await _db.collection('employees').get();

      double minDist = double.infinity;
      String? recognizedUser;

      for (var doc in data.docs) {
        List<dynamic> embeddings = doc['embeddings'];

        for (var emb in embeddings) {
          double dist = _distance(input, emb.cast<double>());

          if (dist < minDist) {
            minDist = dist;
            recognizedUser = doc['name'];
          }
        }
      }

      print("🔥 Min Distance: $minDist");

      // ✅ MATCH FOUND
      if (minDist < threshold && recognizedUser != null) {
        await _markAttendance(recognizedUser);
        return recognizedUser;
      }

      return null;
    } catch (e) {
      print("❌ Recognition Error: $e");
      return null;
    }
  }

  /// 🔷 ATTENDANCE (duplicate avoid)
  Future<void> _markAttendance(String name) async {
    try {
      DateTime now = DateTime.now();
      String today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      var existing = await _db
          .collection('attendance')
          .where('name', isEqualTo: name)
          .where('date', isEqualTo: today)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('attendance').add({
          'name': name,
          'date': today,
          'time': now,
        });

        print("✅ Attendance Marked");
      } else {
        print("⚠️ Already Marked Today");
      }
    } catch (e) {
      print("❌ Attendance Error: $e");
    }
  }

  /// 🔷 DISTANCE (Euclidean)
  double _distance(List<double> a, List<double> b) {
    double sum = 0;

    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }

    return sqrt(sum);
  }
}