import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Native (Android / iOS / desktop): file-backed database in app documents.
Future<Database> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return databaseFactoryIo.openDatabase('${dir.path}/edufocus_offline.db');
}
