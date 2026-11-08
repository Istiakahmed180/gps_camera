import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/widgets/project_cover.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.summary,
    required this.coverPath,
    required this.onTap,
  });

  final ProjectSummary summary;
  final String? coverPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final project = summary.project;
    final count = summary.photoCount;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: SizedBox.square(
                  dimension: 72,
                  child: ProjectCover(path: coverPath, iconSize: 28),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        project.description,
                        style: context.text.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${'@n photo'.trCount('@n photos', count, {'n': '$count'})} · '
                      '${'Updated @date'.trParams({'date': PhotoInfoFormatter.instant(project.updatedAt).split(' · ').first})}',
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
