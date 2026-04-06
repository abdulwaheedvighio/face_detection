import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Rect? faceBox;

  double scanPosition = 0;
  bool scanningDown = true;

  @override
  void initState() {
    super.initState();

    detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableClassification: true,
      ),
    );

    tflite = TFLiteService();
    tflite.loadModel();

    _initCamera();
    _startScanAnimation();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
    );

    controller = CameraController(
      frontCam,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await controller!.initialize();

// ✅ ADD THIS
    await controller!.setExposureMode(ExposureMode.auto);
    await controller!.setFocusMode(FocusMode.auto);
    await controller!.setFlashMode(FlashMode.off);

    _startStream();
    setState(() {});
  }

  void _startScanAnimation() {
    Future.doWhile(() async {
      await Future.delayed(Duration(milliseconds: 30));

      if (!mounted) return false;

      setState(() {
        if (scanningDown) {
          scanPosition += 5;
          if (scanPosition > 300) scanningDown = false;
        } else {
          scanPosition -= 5;
          if (scanPosition < 0) scanningDown = true;
        }
      });

      return true;
    });
  }

  InputImage? _processCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final bytes = allBytes.done().buffer.asUint8List();

      // ✅ FIXED ROTATION
      InputImageRotation rotation;

      switch (controller!.description.sensorOrientation) {
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
        default:
          rotation = InputImageRotation.rotation0deg;
      }

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  void _startStream() {
    controller!.startImageStream((CameraImage image) async {
      frameCount++;

      if (frameCount % 3 != 0) return; // faster detection
      if (loading || isProcessing) return;

      isProcessing = true;

      try {
        final inputImage = _processCameraImage(image);
        if (inputImage == null) {
          isProcessing = false;
          return;
        }

        final faces = await detector.processImage(inputImage);

        print("Faces detected: ${faces.length}"); // ✅ DEBUG

        if (faces.isNotEmpty) {
          Face face = faces.first;
          faceBox = face.boundingBox;

          double rotY = face.headEulerAngleY ?? 0;
          double rotX = face.headEulerAngleX ?? 0;

          double? leftEye = face.leftEyeOpenProbability;
          double? rightEye = face.rightEyeOpenProbability;

          bool isBlinking = false;

          // ✅ RELAXED BLINK
          if (leftEye != null && rightEye != null) {
            if (leftEye < 0.4 && rightEye < 0.4) {
              isBlinking = true;
            }
          }

          bool isPerfect = true;

          // ✅ RELAXED CONDITIONS
          if (rotY.abs() > 15) isPerfect = false;
          if (rotX.abs() > 15) isPerfect = false;
          if (face.boundingBox.width < 80) isPerfect = false;

          if (isPerfect && isBlinking) {
            _updateUI(Colors.green, "Blink detected 👁", "Capturing...");

            if (autoCapture && !loading) {
              autoCapture = false;

              Future.delayed(Duration(milliseconds: 400), () {
                capture();
              });
            }
          } else {
            _updateUI(Colors.orange, "Please Blink 👁", "Anti-spoof check");
          }
        } else {
          faceBox = null;
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

  // 🔥 CLOUDINARY UPLOAD
  Future<String?> uploadToCloudinary(File file) async {
    try {
      var uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/dtcwiqgwc/image/upload');

      var request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = 'face_upload';
      request.fields['folder'] = 'attendance_faces';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data['secure_url'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 🔥 FINAL CAPTURE FUNCTION
  Future<void> capture() async {
    if (controller == null || !controller!.value.isInitialized) return;

    setState(() {
      loading = true;
      status = "Processing...";
    });

    try {
      final XFile file = await controller!.takePicture();

      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await detector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() => status = "Face not detected ❌");
        return;
      }

      Uint8List bytes = await file.readAsBytes();
      Uint8List faceBytes =
      await tflite.cropFace(bytes, faces.first);

      List<double> embedding =
      await tflite.getEmbedding(faceBytes);

      // ✅ REGISTER
      if (widget.isRegister) {
        String? imageUrl =
        await uploadToCloudinary(File(file.path));

        if (imageUrl == null) {
          setState(() => status = "Upload failed ❌");
          return;
        }

        await FirebaseFirestore.instance.collection('employees').add({
          'name': widget.userName,
          'embedding': embedding,
          'image': imageUrl,
          'createdAt': DateTime.now(),
        });

        setState(() => status = "Registered Successfully ✅");
      }

      // ✅ LOGIN
      else {
        String? name =
        await Recognizer().recognize(embedding);

        setState(() {
          status = name != null
              ? "Welcome $name ✅"
              : "Face Not Recognized ❌";
        });
      }
    } catch (e) {
      setState(() => status = "Error ❌");
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

          if (faceBox != null)
            Positioned(
              left: faceBox!.left,
              top: faceBox!.top,
              child: Container(
                width: faceBox!.width,
                height: faceBox!.height,
                decoration: BoxDecoration(
                  border: Border.all(color: boxColor, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          Positioned(
            top: scanPosition,
            left: MediaQuery.of(context).size.width / 2 - 130,
            child: Container(
              width: 260,
              height: 2,
              color: Colors.greenAccent,
            ),
          ),

          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(child: Text(status)),
          ),

          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Center(child: Text(faceDirection)),
          ),
        ],
      ),
    );
  }
}