/// Domain entity representing public application branding and configuration.
class AppConfigEntity {
  final String name;
  final String? tagline;
  final String? supportEmail;
  final String? primaryColor;
  final String? logoUrl;

  const AppConfigEntity({
    required this.name,
    this.tagline,
    this.supportEmail,
    this.primaryColor,
    this.logoUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfigEntity &&
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

  @override
  String toString() =>
      'AppConfigEntity(name: $name, tagline: $tagline, supportEmail: $supportEmail, primaryColor: $primaryColor, logoUrl: $logoUrl)';
}

