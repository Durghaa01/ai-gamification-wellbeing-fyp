import 'package:hive/hive.dart';
import '../../domain/models/assessment.dart';

/// Hive TypeAdapter for AssessmentResult
/// 用于将 AssessmentResult 对象序列化/反序列化到 Hive 数据库
class AssessmentResultAdapter extends TypeAdapter<AssessmentResult> {
  @override
  final int typeId = 0; // 唯一类型 ID

  @override
  AssessmentResult read(BinaryReader reader) {
    final scale = reader.readString();
    final score = reader.readInt();
    final severity = reader.readString();
    final atString = reader.readString();
    final at = DateTime.parse(atString);
    
    return AssessmentResult(
      scale: scale,
      score: score,
      severity: severity,
      at: at,
    );
  }

  @override
  void write(BinaryWriter writer, AssessmentResult obj) {
    writer.writeString(obj.scale);
    writer.writeInt(obj.score);
    writer.writeString(obj.severity);
    writer.writeString(obj.at.toIso8601String());
  }
}

