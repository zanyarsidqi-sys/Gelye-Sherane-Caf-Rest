/// Public four-part release label. Native package version/build stays independent.
/// Increment only for an approved deployment; do not reuse a published label.
class AppReleaseVersion {
  static const label = String.fromEnvironment('APP_RELEASE_VERSION', defaultValue: '1.0.0.1');
}
