/// Represents one active Sanctum Bearer token for the authenticated user.
///
/// Populated from `GET /api/v1/auth/tokens`.
/// See `SessionController::tokens()` in school-api.
class ActiveToken {
  /// Backend integer token ID (used in `DELETE /auth/tokens/{id}`).
  final int id;

  /// Token name (e.g., `'login'`, `'mfa pending'`).
  final String name;

  /// Whether this token corresponds to the current request's session.
  final bool isCurrent;

  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;

  const ActiveToken({
    required this.id,
    required this.name,
    required this.isCurrent,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveToken &&
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

  @override
  String toString() =>
      'ActiveToken(id: $id, name: $name, isCurrent: $isCurrent)';
}

