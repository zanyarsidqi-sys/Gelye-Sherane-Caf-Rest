import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_request_id.dart';
import 'evidence_file.dart';
import 'evidence_browser_stub.dart' if (dart.library.js_interop) 'evidence_browser_web.dart' as browser;

abstract class ExpenseEvidence {
  Future<bool> upload(String expenseId);
  Future<void> download(Map<String,dynamic> evidence);
}
class SupabaseExpenseEvidence implements ExpenseEvidence {
  SupabaseExpenseEvidence(this.client);
  final SupabaseClient client;
  @override
  Future<bool> upload(String expenseId) async {
    final file=await browser.pickEvidenceFile();
    if(file==null)return false;
    final metadata=Map<String,dynamic>.from(await client.rpc('prepare_cafe_expense_evidence',params:{'p_request_id':newCafeRequestId(),'p_expense_id':expenseId,'p_name':file.name,'p_mime':file.mime,'p_size':file.bytes.length}));
    await client.storage.from('cafe-expense-evidence').uploadBinary(metadata['path'],file.bytes,fileOptions:FileOptions(contentType:file.mime,upsert:false));
    await client.rpc('finish_cafe_expense_evidence',params:{'p_id':metadata['id']});
    return true;
  }
  @override
  Future<void> download(Map<String,dynamic> evidence) async {
    final bytes=await client.storage.from('cafe-expense-evidence').download(evidence['object_path']);
    browser.downloadEvidenceFile(EvidenceFile(evidence['file_name'],evidence['mime_type'],bytes));
  }
}
