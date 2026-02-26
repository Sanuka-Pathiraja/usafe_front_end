class ParcelModel {
  final String id;
  final String status;

  const ParcelModel({
    required this.id,
    required this.status,
  });

  factory ParcelModel.fromJson(Map<String, dynamic> json) {
    return ParcelModel(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
