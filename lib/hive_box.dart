import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static Future<void> initialize() async {
    await Hive.openBox('userBox');
    await Hive.openBox('settingsBox');
  }

  static Box get userBox => Hive.box('userBox');
  static Box get settingsBox => Hive.box('settingsBox');
}