// lib/domain/counselor.dart
class Counselor {
  final String id;
  final String name;
  final String specialization;
  final String? imageUrl;
  final String? bio;
  final List<String> expertise;
  final double rating;
  final int yearsOfExperience;

  const Counselor({
    required this.id,
    required this.name,
    required this.specialization,
    this.imageUrl,
    this.bio,
    this.expertise = const [],
    this.rating = 0.0,
    this.yearsOfExperience = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'imageUrl': imageUrl,
      'bio': bio,
      'expertise': expertise,
      'rating': rating,
      'yearsOfExperience': yearsOfExperience,
    };
  }

  factory Counselor.fromJson(Map<String, dynamic> json) {
    return Counselor(
      id: json['id'],
      name: json['name'],
      specialization: json['specialization'],
      imageUrl: json['imageUrl'],
      bio: json['bio'],
      expertise: List<String>.from(json['expertise'] ?? []),
      rating: (json['rating'] ?? 0.0).toDouble(),
      yearsOfExperience: json['yearsOfExperience'] ?? 0,
    );
  }
}