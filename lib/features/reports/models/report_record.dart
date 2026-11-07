import 'dart:io';

import 'package:gps_camera/features/reports/models/report_models.dart';

/// The JSON written next to each generated PDF.
class ReportRecord {
  const ReportRecord({
    required this.fileName,
    required this.type,
    required this.title,
    required this.generatedAt,
    required this.photoCount,
    required this.pageCount,
    this.projectId,
    this.projectName,
    this.schemaVersion = currentSchemaVersion,
  });

  factory ReportRecord.fromJson(Map<String, dynamic> json) => ReportRecord(
    schemaVersion: json['schemaVersion'] as int,
    fileName: json['fileName'] as String,
    type: ReportType.values.byName(json['type'] as String),
    title: json['title'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    photoCount: json['photoCount'] as int,
    pageCount: json['pageCount'] as int,
    projectId: json['projectId'] as String?,
    projectName: json['projectName'] as String?,
  );

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String fileName;
  final ReportType type;
  final String title;
  final DateTime generatedAt;
  final int photoCount;
  final int pageCount;
  final String? projectId;
  final String? projectName;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'fileName': fileName,
    'type': type.name,
    'title': title,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'photoCount': photoCount,
    'pageCount': pageCount,
    'projectId': projectId,
    'projectName': projectName,
  };
}

/// A PDF in the reports folder, with its record when readable.
class ReportFile {
  const ReportFile({
    required this.file,
    required this.sizeBytes,
    required this.modifiedAt,
    this.record,
  });

  final File file;
  final int sizeBytes;
  final DateTime modifiedAt;
  final ReportRecord? record;

  String get fileName => file.uri.pathSegments.last;

  DateTime get generatedAt => record?.generatedAt ?? modifiedAt;
}
