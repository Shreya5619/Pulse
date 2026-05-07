import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_settings/app_settings.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionExecutor {
  static void execute(BuildContext context, AppState state, Map<String, dynamic> action) {
    state.acceptAction(action);
    final id = action['id'] as String;
    String message = "Action accepted: ${action['title']}";

    if (id.contains("NOTIFICATIONS")) {
      message = "Focus mode active. Opening notification settings...";
      state.openNotificationSettings();
    } else if (id.contains("BATTERY_SAVER")) {
      message = "Redirecting to Battery settings...";
      if (Platform.isAndroid) {
        const intent = AndroidIntent(
          action: 'android.settings.BATTERY_SAVER_SETTINGS',
        );
        intent.launch();
      } else {
        AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
      }
    } else if (id.contains("CHARGING")) {
      message = "Planning charging stop and updating risks...";
      state.planBriefChargingStop();
      state.setTabIndex(1); // Navigate to Daily Pulse
    } else if (id.contains("SETTINGS")) {
      message = "Opening settings...";
      if (id.contains("BATTERY")) {
        AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
      } else if (id.contains("NOTIFICATION")) {
        state.openNotificationSettings();
      } else {
        AppSettings.openAppSettings();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
