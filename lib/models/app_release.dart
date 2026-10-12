class AppRelease {
  AppRelease(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'].toString();
  String get version => data['version'] as String;
  String get platform => data['platform'] as String;
  String get channel => data['channel'] as String;
  String get status => data['status'] as String;
  int get revision => data['revision'] as int;
  String get notes => data['notes'] as String;
  String get artifactUrl => data['artifact_url'] as String;
  String get sha256 => data['sha256'] as String;
  String get createdAt => data['created_at'].toString();
  static const platforms = ['web', 'android', 'ios', 'windows'];
  static const channels = ['test', 'stable'];
  static const reviewChecks = <String, String>{
    'smoke': 'Sign-in, MFA and navigation tested on the target platform',
    'permissions': 'Permissions and denied-access checks reviewed',
    'backend': 'Required backend changes applied and verified',
    'backup': 'Backup and recovery procedure verified',
    'artifact': 'Release link and SHA-256 checked against the actual build',
  };
  static String? validateDraft({required String version, required String notes,
      required String url, required String sha256}) {
    if (!RegExp(r'^\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,9}$').hasMatch(version)) {
      return 'Use a version such as 1.0.0.30.';
    }
    if (notes.trim().length < 10 || notes.length > 4000) {
      return 'Release notes must contain 10–4000 characters.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.port != 443 || uri.hasFragment ||
        uri.hasQuery || url.length > 1000) {
      return 'Enter an HTTPS release URL without credentials, query or fragment.';
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      return 'Enter the actual build’s 64-character SHA-256 checksum.';
    }
    return null;
  }
}
