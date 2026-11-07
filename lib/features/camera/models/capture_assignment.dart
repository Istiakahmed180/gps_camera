import 'dart:io';

/// The result of filing a new capture into a project.
sealed class CaptureAssignment {
  const CaptureAssignment();
}

class NotAssigned extends CaptureAssignment {
  const NotAssigned();
}

class AssignedToProject extends CaptureAssignment {
  const AssignedToProject(this.projectName);

  final String projectName;
}

class AssignmentFailed extends CaptureAssignment {
  const AssignmentFailed(this.projectName);

  final String projectName;
}

/// Files a saved capture into the camera's active project, if any. Must
/// never throw: capture works with or without projects.
abstract interface class CaptureAssigner {
  Future<CaptureAssignment> assignCapture(File photo);
}
