/// Extended user profile information beyond basic authentication
class UserInfo {
  UserInfo({
    required this.userId,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.bio,
    this.profileImageUrl,
    this.location,
    this.dateOfBirth,
    this.gender,
    this.preferences = const {},
    this.lastProfileUpdate,
    required this.createdAt,
  });
  
  /// User ID (Firebase UID)
  final String userId;
  /// Email address
  final String email;
  /// Display name from AppUser
  final String displayName;
  /// Phone number (optional)
  final String? phoneNumber;
  /// User bio/about (max 500 chars)
  final String? bio;
  /// Profile image URL
  final String? profileImageUrl;
  /// City or region
  final String? location;
  /// Date of birth for age calculation
  final DateTime? dateOfBirth;
  /// Gender (optional)
  final String? gender;
  /// User preferences: {darkMode, notifications, privacyLevel, emailNotifications}
  final Map<String, dynamic> preferences;
  /// Last update timestamp
  final DateTime? lastProfileUpdate;
  /// Profile creation timestamp
  final DateTime createdAt;

  /// Calculate age from dateOfBirth
  int? get age {
    if (dateOfBirth == null) return null;
    final today = DateTime.now();
    int calculatedAge = today.year - dateOfBirth!.year;
    if (today.month < dateOfBirth!.month ||
        (today.month == dateOfBirth!.month && today.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  /// Calculate profile completeness (0-100)
  int get profileCompletenessPercentage {
    int completed = 0;
    int total = 7; // Total optional fields to check

    if (phoneNumber != null && phoneNumber!.isNotEmpty) completed++;
    if (bio != null && bio!.isNotEmpty) completed++;
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) completed++;
    if (location != null && location!.isNotEmpty) completed++;
    if (dateOfBirth != null) completed++;
    if (gender != null && gender!.isNotEmpty) completed++;
    if (preferences.isNotEmpty) completed++;

    return ((completed / total) * 100).toInt();
  }

  /// Copy with method for updating specific fields
  UserInfo copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? bio,
    String? profileImageUrl,
    String? location,
    DateTime? dateOfBirth,
    String? gender,
    Map<String, dynamic>? preferences,
    DateTime? lastProfileUpdate,
    DateTime? createdAt,
  }) {
    return UserInfo(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      location: location ?? this.location,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      preferences: preferences ?? this.preferences,
      lastProfileUpdate: lastProfileUpdate ?? this.lastProfileUpdate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'location': location,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'preferences': preferences,
      'lastProfileUpdate': lastProfileUpdate,
      'createdAt': createdAt,
    };
  }

  /// Create from Firestore Map
  factory UserInfo.fromMap(Map<String, dynamic> data) {
    return UserInfo(
      userId: data['userId'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      phoneNumber: data['phoneNumber'] as String?,
      bio: data['bio'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      location: data['location'] as String?,
      dateOfBirth: data['dateOfBirth'] != null
          ? DateTime.parse(data['dateOfBirth'] as String)
          : null,
      gender: data['gender'] as String?,
      preferences: (data['preferences'] as Map?)?.cast<String, dynamic>() ?? {},
      lastProfileUpdate: data['lastProfileUpdate'] != null
          ? DateTime.parse(data['lastProfileUpdate'] as String)
          : null,
      createdAt: DateTime.parse(data['createdAt'] as String),
    );
  }

  /// Validation methods
  String? validatePhoneNumber() {
    if (phoneNumber == null || phoneNumber!.isEmpty) return null;
    // Simple validation: at least 10 digits
    final digits = phoneNumber!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Phone number must have at least 10 digits';
    }
    return null;
  }

  String? validateBio() {
    if (bio == null || bio!.isEmpty) return null;
    if (bio!.length > 500) {
      return 'Bio must be less than 500 characters';
    }
    return null;
  }

  String? validateAge() {
    if (dateOfBirth == null) return null;
    final calculatedAge = age;
    if (calculatedAge != null && calculatedAge < 13) {
      return 'You must be at least 13 years old';
    }
    if (calculatedAge != null && calculatedAge > 150) {
      return 'Please enter a valid date of birth';
    }
    return null;
  }

  String? validateLocation() {
    if (location == null || location!.isEmpty) return null;
    if (location!.length < 2) {
      return 'Location must be at least 2 characters';
    }
    return null;
  }

  /// Validate all fields
  Map<String, String> validateAll() {
    final errors = <String, String>{};
    
    final phoneError = validatePhoneNumber();
    if (phoneError != null) errors['phoneNumber'] = phoneError;
    
    final bioError = validateBio();
    if (bioError != null) errors['bio'] = bioError;
    
    final ageError = validateAge();
    if (ageError != null) errors['dateOfBirth'] = ageError;
    
    final locationError = validateLocation();
    if (locationError != null) errors['location'] = locationError;
    
    return errors;
  }

  @override
  String toString() {
    return 'UserInfo(userId: $userId, email: $email, displayName: $displayName, '
        'phoneNumber: $phoneNumber, location: $location, age: $age)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfo &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          email == other.email &&
          displayName == other.displayName &&
          phoneNumber == other.phoneNumber &&
          bio == other.bio &&
          profileImageUrl == other.profileImageUrl &&
          location == other.location &&
          dateOfBirth == other.dateOfBirth &&
          gender == other.gender &&
          preferences == other.preferences;

  @override
  int get hashCode =>
      userId.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      phoneNumber.hashCode ^
      bio.hashCode ^
      profileImageUrl.hashCode ^
      location.hashCode ^
      dateOfBirth.hashCode ^
      gender.hashCode ^
      preferences.hashCode;
}
