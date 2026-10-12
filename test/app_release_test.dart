import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/models/app_release.dart';
import 'package:gelye_cafe_rest/shared/release_update_notice.dart';

void main() {
  test('four-part numeric versions compare correctly', () {
    expect(ReleaseUpdateNotice.isNewer('1.0.0.10', '1.0.0.9'), isTrue);
    expect(ReleaseUpdateNotice.isNewer('1.0.0.1', '1.0.0.1'), isFalse);
    expect(ReleaseUpdateNotice.isNewer('1.0.0.1', '1.0.0.2'), isFalse);
    expect(ReleaseUpdateNotice.isNewer('2.0.0.1', '1.99.99.99'), isTrue);
    expect(ReleaseUpdateNotice.isNewer('latest', '1.0.0.1'), isFalse);
  });
  test('draft rejects invalid versions, URLs and checksums', () {
    String? validate(String version, String url, String checksum) =>
      AppRelease.validateDraft(version: version, notes: 'Reviewed release description', url: url, sha256: checksum);
    final checksum = List.filled(64, 'a').join();
    expect(validate('1.0.0.1', 'https://cafe.gelyesheranecompany.com/', checksum), isNull);
    expect(validate('1.0.0+1', 'https://cafe.gelyesheranecompany.com/', checksum), isNotNull);
    expect(validate('1.0.0.1', 'http://cafe.gelyesheranecompany.com/', checksum), isNotNull);
    expect(validate('1.0.0.1', 'https://user:password@cafe.gelyesheranecompany.com/', checksum), isNotNull);
    expect(validate('1.0.0.1', 'https://cafe.gelyesheranecompany.com/', 'not-a-hash'), isNotNull);
  });
}
