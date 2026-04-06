import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:vibration/vibration.dart';

import 'recognizer.dart';
import 'tflite_service.dart';

class FaceScreen extends StatefulWidget {
  final String userName;
  final bool isRegister;

  FaceScreen({required this.userName, required this.isRegister});

  @override
  _FaceScreenState createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> {
  CameraController? controller;
  late FaceDetector detector;
  late TFLiteService tflite;

  bool loading = false;
  bool isProcessing = false;
  bool autoCapture = true;

  int frameCount = 0;

  String status = "Align your face";
  String faceDirection = "Looking for face...";
  Color boxColor = Colors.red;

  @override
  void initState() {
    super.initState();

    detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    tflite = TFLiteService();
    tflite.loadModel();

    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
    );

    controller = CameraController(frontCam, ResolutionPreset.medium);
    await controller!.initialize();

    _startStream();

    setState(() {});
  }

  void _startStream() {
    controller!.startImageStream((image) async {
      frameCount++;

      // 🔥 Process every 3rd frame (IMPORTANT)
      if (frameCount % 3 != 0) return;

      if (loading || isProcessing) return;

      isProcessing = true;

      try {
        final WriteBuffer buffer = WriteBuffer();
        for (var plane in image.planes) {
          buffer.putUint8List(plane.bytes);
        }
        final bytes = buffer.done().buffer.asUint8List();

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );

        final faces = await detector.processImage(inputImage);

        if (faces.isNotEmpty) {
          Face face = faces.first;

          double rotY = face.headEulerAngleY ?? 0;
          double rotX = face.headEulerAngleX ?? 0;

          bool isPerfect = true;

          if (rotY.abs() > 8) isPerfect = false;
          if (rotX.abs() > 8) isPerfect = false;

          if (face.boundingBox.width < 150) isPerfect = false;

          if (isPerfect) {
            _updateUI(Colors.green, "Perfect ✅", "Hold still...");

            // 🔥 Auto capture
            if (autoCapture && !loading) {
              autoCapture = false;

              Future.delayed(Duration(milliseconds: 700), () {
                capture();
              });
            }

          } else {
            _updateUI(Colors.orange, "Adjust face ⚠️", "Align properly");

            // 📳 Vibrate
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 100);
            }
          }

        } else {
          _updateUI(Colors.red, "No Face ❌", "No face detected");
        }

      } catch (e) {
        print("Error: $e");
      }

      isProcessing = false;
    });
  }

  void _updateUI(Color color, String direction, String stat) {
    if (!mounted) return;

    setState(() {
      boxColor = color;
      faceDirection = direction;
      status = stat;
    });
  }

  Future<void> capture() async {
    if (controller == null) return;

    setState(() {
      loading = true;
      status = "Processing...";
    });

    try {
      final file = await controller!.takePicture();

      final input = InputImage.fromFilePath(file.path);
      final faces = await detector.processImage(input);

      if (faces.isEmpty) {
        setState(() {
          status = "No face detected ❌";
        });
        return;
      }

      Uint8List bytes = await File(file.path).readAsBytes();
      Uint8List faceBytes = await tflite.cropFace(bytes, faces.first);
      List<double> embedding = await tflite.getEmbedding(faceBytes);

      if (widget.isRegister) {
        await Recognizer().register(widget.userName, embedding, "");

        setState(() {
          status = "Registered Successfully ✅";
        });
      } else {
        String? name = await Recognizer().recognize(embedding);

        setState(() {
          status = name != null
              ? "Welcome $name ✅"
              : "Face Not Recognized ❌";
        });
      }

    } catch (e) {
      setState(() {
        status = "Error ❌";
      });
    } finally {
      setState(() {
        loading = false;
        autoCapture = true;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(controller!),

          // 🔥 Face Guide
          Center(
            child: Container(
              width: 260,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: boxColor, width: 4),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),

          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                status,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),

          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                faceDirection,
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}