class UserModel {
  final String name;
  final String email;
  final String blood;
  final String age;
  final String weight;

  const UserModel({
    required this.name,
    required this.email,
    required this.blood,
    required this.age,
    required this.weight,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      blood: json['blood'] ?? '--',
      age: json['age'] ?? '--',
      weight: json['weight'] ?? '--',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'blood': blood,
      'age': age,
      'weight': weight,
    };
  }
}
