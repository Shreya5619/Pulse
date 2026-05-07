import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyUserId = 'user_id';

  /// Gets the stored user ID or generates a new one if it doesn't exist.
  static Future<String> getUserId() async {
    String? userId = await _storage.read(key: _keyUserId);

    if (userId == null) {
      userId = const Uuid().v4();
      await _storage.write(key: _keyUserId, value: userId);
      debugPrint('Generated new local UUID: $userId');
    } else {
      debugPrint('Loaded existing local UUID: $userId');
    }

    return userId;
  }

  /// Clears the stored user ID (for testing purposes or data clear).
  static Future<void> clearUserId() async {
    await _storage.delete(key: _keyUserId);
  }
}
