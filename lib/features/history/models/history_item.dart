import '../../speed_test/models/speed_result.dart';

class HistoryItem {
  final String id;
  final SpeedResult result;

  const HistoryItem({required this.id, required this.result});

  Map<String, dynamic> toJson() => {
        'id': id,
        'result': result.toJson(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String? ?? '',
      result: SpeedResult.fromJson(
        Map<String, dynamic>.from(json['result'] as Map? ?? {}),
      ),
    );
  }
}
