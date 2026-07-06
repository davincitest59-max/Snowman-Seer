import 'package:path/path.dart' as p;

import '../../platform/app_directories.dart';

Future<String> oceanBabyDatabasePath() async {
  final dir = await const AppDirectoriesBridge().applicationSupportDirectory();
  return p.join(dir.path, 'ocean_baby.sqlite');
}
