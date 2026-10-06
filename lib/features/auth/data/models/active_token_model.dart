import 'package:school_app/features/auth/domain/entities/active_token.dart';

/// Data Transfer Object for items in `GET /api/v1/auth/tokens` response.
///
/// Response item shape (verified from SessionController::tokens()):
/// ```json
/// {
///   "id": 42,
///   "name": "login",
///   "current": true,
///   "created_at": "2026-10-06T15:00:00Z",
///   "last_used_at": "2026-10-06T16:00:00Z",
///   "expires_at": "2026-11-05T15:00:00Z"
/// }
/// ```
class ActiveTokenModel {
  final int id;
  final String name;
  final bool isCurrent;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;

  const ActiveTokenModel({
    required this.id,
    required this.name,
    required this.isCurrent,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
  });

  factory ActiveTokenModel.fromJson(Map<String, dynamic> json) =>
      ActiveTokenModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        isCurrent: json['current'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        lastUsedAt: json['last_used_at'] != null
            ? DateTime.tryParse(json['last_used_at'] as String)
            : null,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
      );

  ActiveToken toEntity() => ActiveToken(
        id: id,
        name: name,
        isCurrent: isCurrent,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt,
        expiresAt: expiresAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveTokenModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isCurrent == other.isCurrent &&
          createdAt == other.createdAt &&
          lastUsedAt == other.lastUsedAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        isCurrent,
        createdAt,
        lastUsedAt,
        expiresAt,
      );
}

