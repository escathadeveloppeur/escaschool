import 'package:hive/hive.dart';
part 'evaluation_model.g.dart';

@HiveType(typeId: 11)
class EvaluationModel extends HiveObject {
  @HiveField(0)
  int studentKey;       // clé hive étudiant
  @HiveField(1)
  int classKey;         // clé hive classe
  @HiveField(2)
  String subject;       // matière
  @HiveField(3)
  String evaluationName; // ex: "DS1", "Contrôle 2"
  @HiveField(4)
  double score;         // note numérique
  @HiveField(5)
  double maxScore;      // maximum possible
  @HiveField(6)
  DateTime date;

  EvaluationModel({
    required this.studentKey,
    required this.classKey,
    required this.subject,
    required this.evaluationName,
    required this.score,
    required this.maxScore,
    required this.date,
  });
}
