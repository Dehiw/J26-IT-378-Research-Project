import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';
class AnalysisDraft {
  final XFile? bee,frame;
  final Map<String,dynamic>? result;
  const AnalysisDraft(this.bee,this.frame,this.result);
}
class EnvironmentAnalysisSession {
  static final Map<String,AnalysisDraft> _drafts={};
  static String _key(String? hive)=>'${AuthService.instance.currentUser?.id ?? 'guest'}/${hive ?? 'unsaved'}';
  static AnalysisDraft? get(String? hive)=>_drafts[_key(hive)];
  static void put(String? hive,XFile? bee,XFile? frame,Map<String,dynamic>? result){_drafts[_key(hive)]=AnalysisDraft(bee,frame,result);}
}
