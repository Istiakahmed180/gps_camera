import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:gps_camera/features/camera/models/capture_assignment.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/active_project_store.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// The camera's optional active project. New captures are added to it;
/// changing it never touches photos already taken.
class ActiveProjectController extends GetxController
    implements CaptureAssigner {
  ActiveProjectController(this._repo, this._store);

  final ProjectRepository _repo;
  final ActiveProjectStore _store;

  final Rxn<Project> active = Rxn<Project>();

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  /// Restores the remembered project. A deleted or archived project is
  /// forgotten; a database error keeps the saved choice for next time.
  Future<void> load() async {
    final id = _store.load();
    if (id == null) return;
    try {
      final project = await _repo.find(id);
      if (project == null || project.isArchived) {
        active.value = null;
        await _store.save(null);
      } else {
        active.value = project;
      }
    } catch (_) {
      active.value = null;
    }
  }

  Future<List<Project>> options() => _repo.activeProjects();

  Future<void> select(Project? project) async {
    active.value = project;
    await _store.save(project?.id);
  }

  @override
  Future<CaptureAssignment> assignCapture(File photo) async {
    final project = active.value;
    if (project == null) return const NotAssigned();
    try {
      await _repo.assign(
        PhotoRefs.original(photo.uri.pathSegments.last),
        project.id,
      );
      return AssignedToProject(project.name);
    } on ProjectValidationException {
      // Deleted or archived since it was chosen: stop using it.
      await select(null);
      return AssignmentFailed(project.name);
    } catch (_) {
      return AssignmentFailed(project.name);
    }
  }
}
