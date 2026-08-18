import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_application_mhproj/services/local_data_store.dart';

bool _hiveInitializedForTests = false;
bool _storeInitialized = false;
Directory? _tempDir;

Future<void> ensureTestStoreInitialized({bool reset = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (!_hiveInitializedForTests) {
    _tempDir = await Directory.systemTemp.createTemp('mindwell_test_');
    Hive.init(_tempDir!.path);
    _hiveInitializedForTests = true;
  }

  if (!_storeInitialized || reset) {
    await LocalDataStore.instance.init(forceReset: reset || !_storeInitialized);
    _storeInitialized = true;
  }
}
