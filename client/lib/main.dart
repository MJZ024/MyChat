import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use pid-based directory so multiple instances can run simultaneously
  final dataDir = Directory('${Directory.current.path}/.mychat_data/inst_$pid');
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }
  Hive.init(dataDir.path);

  if (!Hive.isBoxOpen('auth')) {
    await Hive.openBox('auth');
  }
  if (!Hive.isBoxOpen('settings')) {
    await Hive.openBox('settings');
  }
  runApp(const ProviderScope(child: MyApp()));
}
