import 'package:flutter/material.dart';

enum Role { user, clinic, admin }

Role roleFromString(String? value) {
  if (value == null) {
    return Role.user;
  }
  return Role.values.firstWhere(
    (role) => role.name.toLowerCase() == value.toLowerCase(),
    orElse: () => Role.user,
  );
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.age,
    this.gender,
    this.notes = '',
    this.inviteCode,
  });
  final String id;
  final String name;
  final String email;
  final Role role;
  final int? age;
  final String? gender;
  String notes;
  final String? inviteCode;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    Role? role,
    int? age,
    String? gender,
    String? notes,
    String? inviteCode,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      notes: notes ?? this.notes,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> data, {required String id}) {
    return AppUser(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      email: (data['email'] as String?)?.trim() ?? '',
      role: roleFromString(data['role'] as String?),
      age: data['age'] is int ? data['age'] as int : null,
      gender: data['gender'] as String?,
      notes: data['notes'] as String? ?? '',
      inviteCode: data['inviteCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'role': role.name,
      'age': age,
      'gender': gender,
      'notes': notes,
      'inviteCode': inviteCode,
    };
  }
}

class Clinic {
  Clinic({
    required this.id,
    required this.name,
    this.address,
    List<AppUser>? patients,
  }) : patients = patients ?? [];
  final String id;
  final String name;
  final String? address;
  final List<AppUser> patients;
}
