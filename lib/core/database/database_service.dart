import 'package:drift/drift.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/database/app_database.dart';

/// Owns the app's single database connection.
class DatabaseService extends GetxService {
  DatabaseService([QueryExecutor? executor]) : db = AppDatabase(executor);

  final AppDatabase db;

  @override
  Future<void> onClose() async {
    await db.close();
    super.onClose();
  }
}
