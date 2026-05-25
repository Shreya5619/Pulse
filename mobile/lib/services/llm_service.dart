import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/device_context.dart';
import '../config/backend_config.dart';

class LlmService {
  Future<Map<String, dynamic>> summarizeSurge(List<NotificationInfo> notifications) async {
    if (notifications.isEmpty) {
      return {
        'highlight': 'No recent notifications',
        'urgent': [],
        'important': [],
        'noiseCount': 0,
      };
    }

    try {
      debugPrint('[LlmService] Summarizing ${notifications.length} notifications via API...');
      
      const host = BackendConfig.host;
      final String baseUrl;
      if (host.startsWith('http://') || host.startsWith('https://')) {
        baseUrl = host;
      } else if (host.contains(':')) {
        baseUrl = 'http://$host';
      } else if (host.contains('192.168.') || host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2' || host.startsWith('10.')) {
        baseUrl = 'http://$host:8080';
      } else {
        baseUrl = 'https://$host';
      }
      final url = Uri.parse('$baseUrl/api/summarize-notifications');
      
      // Convert NotificationInfo objects to maps for the JSON body
      final body = jsonEncode({
        'notifications': notifications.map((n) => n.toMap()).toList(),
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      
      debugPrint('[LlmService] API error: ${response.statusCode} - ${response.body}');
      
    } catch (e) {
      debugPrint('[LlmService] Failed to reach LLM API: $e');
    }

    // Fallback if API fails or is unreachable
    return _fallbackSummarize(notifications);
  }

  Map<String, dynamic> _fallbackSummarize(List<NotificationInfo> notifications) {
    debugPrint('[LlmService] Using fallback summarization');
    final byApp = <String, int>{};
    for (var n in notifications) {
      byApp[n.appName] = (byApp[n.appName] ?? 0) + 1;
    }

    final topApp = byApp.entries.isNotEmpty 
        ? byApp.entries.reduce((a, b) => a.value > b.value ? a : b).key 
        : 'Unknown';

    String highlight = "Busy period detected ($topApp active)";
    List<String> urgent = [];
    List<String> important = [];
    int noiseCount = 0;

    for (var n in notifications) {
      if (n.category == 'URGENT_OTP' || n.text.toLowerCase().contains('otp') || n.text.toLowerCase().contains('code')) {
        urgent.add("${n.appName}: ${n.title}");
      } else if (n.category == 'IMPORTANT_SENDER' || n.appName.toLowerCase().contains('slack') || n.appName.toLowerCase().contains('whatsapp')) {
        important.add("${n.appName}: ${n.title}");
      } else {
        noiseCount++;
      }
    }

    if (urgent.isNotEmpty) {
      highlight = "Action required: ${urgent.first}";
    } else if (important.isNotEmpty) {
      highlight = "Updates from ${important.first.split(':').first}";
    } else {
      highlight = "$noiseCount notifications ignored";
    }

    return {
      'highlight': highlight,
      'digest': 'Filtered $noiseCount notifications. Top activity from $topApp.',
      'actionItems': [...urgent.take(2), ...important.take(3)].toList(),
    };
  }
}
