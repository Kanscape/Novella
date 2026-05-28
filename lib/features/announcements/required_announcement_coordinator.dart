import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/features/announcements/announcement_models.dart';
import 'package:novella/features/announcements/announcement_provider.dart';
import 'package:novella/features/announcements/required_announcement_sheet.dart';
import 'package:novella/features/settings/pages/about_settings_page.dart';

final requiredAnnouncementCoordinatorProvider =
    Provider<RequiredAnnouncementCoordinator>(
      (_) => RequiredAnnouncementCoordinator(),
    );

class RequiredAnnouncementCoordinator {
  final _logger = Logger('RequiredAnnouncementCoordinator');
  bool _checkingOrShowing = false;

  Future<void> check({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    if (_checkingOrShowing) {
      return;
    }

    final pageContext = context;
    _checkingOrShowing = true;

    try {
      while (pageContext.mounted) {
        var state = await ref.read(announcementProvider.future);
        if (!pageContext.mounted) {
          return;
        }

        if (state.appErrorMessage != null) {
          await ref.read(announcementProvider.notifier).refresh(silent: true);
          if (!pageContext.mounted) {
            return;
          }
          state = await ref.read(announcementProvider.future);
          if (!pageContext.mounted) {
            return;
          }
        }

        if (state.requiredUnreadAppAnnouncements.isEmpty) {
          return;
        }

        final announcement = state.requiredUnreadAppAnnouncements.first;
        final action = await showRequiredAnnouncementSheet(
          context: pageContext,
          ref: ref,
          announcement: announcement,
        );
        if (!pageContext.mounted) {
          return;
        }

        if (action == AnnouncementCompletionActionType.openAbout) {
          await AppRouteLauncher.pushDetail(
            pageContext,
            (_) => const AboutSettingsPage(),
          );
        }
      }
    } catch (error) {
      _logger.warning('Failed to check required announcements: $error');
    } finally {
      _checkingOrShowing = false;
    }
  }
}
