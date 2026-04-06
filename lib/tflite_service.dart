import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  late Interpreter interpreter;

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/model/mobilefacenet.tflite');
    print("TFLite Model Loaded ✅");
  }

  Future<List<double>> getEmbedding(Uint8List bytes) async {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return [];

    // ✅ Resize (IMPORTANT)
    img.Image resized = img.copyResize(image, width: 112, height: 112);

    // ✅ Convert to input tensor
    var input = List.generate(
      1,
          (_) => List.generate(
        112,
            (y) => List.generate(
          112,
              (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128,
              (pixel.g - 127.5) / 128,
              (pixel.b - 127.5) / 128,
            ];
          },
        ),
      ),
    );

    var output = List.generate(1, (_) => List.filled(192, 0.0));

    interpreter.run(input, output);

    // ✅ L2 NORMALIZATION (VERY IMPORTANT 🔥)
    List<double> embedding = List<double>.from(output[0]);

    double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    embedding = embedding.map((e) => e / norm).toList();

    return embedding;
  }

  Future<Uint8List> cropFace(Uint8List bytes, dynamic face) async {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final rect = face.boundingBox;

    // ✅ Better crop (add margin)
    int margin = 20;

    int left = (rect.left - margin).toInt().clamp(0, image.width - 1);
    int top = (rect.top - margin).toInt().clamp(0, image.height - 1);
    int right = (rect.right + margin).toInt().clamp(0, image.width);
    int bottom = (rect.bottom + margin).toInt().clamp(0, image.height);

    int width = right - left;
    int height = bottom - top;

    img.Image cropped = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    return Uint8List.fromList(img.encodeJpg(cropped));
  }
}