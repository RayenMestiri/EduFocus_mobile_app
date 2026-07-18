import 'package:sembast_web/sembast_web.dart';

/// Web: IndexedDB-backed database.
Future<Database> openAppDatabase() {
  return databaseFactoryWeb.openDatabase('edufocus_offline.db');
}
