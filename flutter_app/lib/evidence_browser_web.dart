import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'evidence_file.dart';

Future<EvidenceFile?> pickEvidenceFile() {
  final result = Completer<EvidenceFile?>();
  final input = web.HTMLInputElement()..type='file'..accept='.pdf,.jpg,.jpeg,.png'..style.display='none';
  void finish(EvidenceFile? file, [Object? error]) {
    input.remove();
    if (result.isCompleted) return;
    if (error != null) { result.completeError(error); } else { result.complete(file); }
  }
  input.addEventListener('cancel', ((web.Event event) => finish(null)).toJS);
  input.addEventListener('change', ((web.Event event) {
    final file = input.files?.item(0);
    if (file == null) { finish(null); return; }
    if (file.size < 1 || file.size > 10485760) { finish(null, const FormatException('Choose a file up to 10 MB.')); return; }
    final lower = file.name.toLowerCase();
    final mime = lower.endsWith('.pdf') ? 'application/pdf' : lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) ? 'image/jpeg' : '';
    if (mime.isEmpty) { finish(null, const FormatException('Choose a PDF, JPEG or PNG.')); return; }
    file.arrayBuffer().toDart.then((buffer) => finish(EvidenceFile(file.name,mime,buffer.toDart.asUint8List())), onError:(Object error) => finish(null,error));
  }).toJS);
  web.document.body!.appendChild(input);
  input.click();
  return result.future;
}
void downloadEvidenceFile(EvidenceFile file) {
  final blob = web.Blob([file.bytes.toJS].toJS,web.BlobPropertyBag(type:file.mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()..href=url..download=file.name.replaceAll(RegExp(r'[\\/\r\n]'),'_');
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds:30),()=>web.URL.revokeObjectURL(url));
}
