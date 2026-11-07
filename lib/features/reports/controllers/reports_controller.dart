import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/features/reports/models/report_record.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';

enum ReportsStatus { loading, ready, error }

class ReportsController extends GetxController {
  ReportsController(this.service);

  final ReportService service;

  final Rx<ReportsStatus> status = ReportsStatus.loading.obs;
  final RxList<ReportFile> reports = <ReportFile>[].obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      reports.assignAll(await service.history());
      status.value = ReportsStatus.ready;
    } catch (_) {
      status.value = ReportsStatus.error;
    }
  }

  /// Deletes only the PDF and its record. Returns an error message or null.
  Future<String?> delete(ReportFile report) async {
    try {
      await service.delete(report);
      await load();
      return null;
    } catch (_) {
      await load();
      return 'The report could not be deleted.';
    }
  }
}
