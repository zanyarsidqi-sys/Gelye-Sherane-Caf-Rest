import 'dart:typed_data';
class EvidenceFile {
  const EvidenceFile(this.name, this.mime, this.bytes);
  final String name, mime;
  final Uint8List bytes;
}
