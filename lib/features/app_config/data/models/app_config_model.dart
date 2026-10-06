import 'package:school_app/features/app_config/domain/entities/app_config_entity.dart';

/// Data Transfer Object for public application configuration.
///
/// Matches payload from `GET /api/v1/app-config`.
class AppConfigModel {
  final String name;
  final String? tagline;
  final String? supportEmail;
  final String? primaryColor;
  final String? logoUrl;

  const AppConfigModel({
    required this.name,
    this.tagline,
    this.supportEmail,
    this.primaryColor,
    this.logoUrl,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      name: json['name'] as String? ?? 'School App',
      tagline: json['tagline'] as String?,
      supportEmail: json['support_email'] as String?,
      primaryColor: json['primary_color'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tagline': tagline,
      'support_email': supportEmail,
      'primary_color': primaryColor,
      'logo_url': logoUrl,
    };
  }

  AppConfigEntity toEntity() {
    return AppConfigEntity(
      name: name,
      tagline: tagline,
      supportEmail: supportEmail,
      primaryColor: primaryColor,
      logoUrl: logoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfigModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          tagline == other.tagline &&
          supportEmail == other.supportEmail &&
          primaryColor == other.primaryColor &&
          logoUrl == other.logoUrl;

  @override
  int get hashCode => Object.hash(
        name,
        tagline,
        supportEmail,
        primaryColor,
        logoUrl,
      );
}

