import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/community_models.dart';

class CommunityPostDraft {
  const CommunityPostDraft({
    required this.category,
    required this.title,
    required this.content,
    this.imagePath,
    required this.savedAt,
  });

  final PostCategory category;
  final String title;
  final String content;
  final String? imagePath;
  final DateTime savedAt;

  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'title': title,
        'content': content,
        'image_path': imagePath,
        'saved_at': savedAt.toIso8601String(),
      };

  factory CommunityPostDraft.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString();
    return CommunityPostDraft(
      category: rawCategory == PostCategory.qa.name
          ? PostCategory.qa
          : PostCategory.free,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imagePath: json['image_path']?.toString(),
      savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class CommunityDraftStorage {
  CommunityDraftStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String accountKey) {
    final normalized = accountKey.trim().toLowerCase();
    final encoded = base64Url.encode(utf8.encode(normalized.isEmpty ? 'guest' : normalized));
    return 'community_post_draft_$encoded';
  }

  Future<CommunityPostDraft?> read(String accountKey) async {
    final raw = await _storage.read(key: _key(accountKey));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CommunityPostDraft.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String accountKey, CommunityPostDraft draft) async {
    if (draft.isEmpty) {
      await clear(accountKey);
      return;
    }
    await _storage.write(
      key: _key(accountKey),
      value: jsonEncode(draft.toJson()),
    );
  }

  Future<void> clear(String accountKey) => _storage.delete(key: _key(accountKey));
}
