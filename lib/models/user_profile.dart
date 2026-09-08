import 'package:cloud_firestore/cloud_firestore.dart';

/// Gender options offered on the Register screen.
const List<String> kGenderOptions = ['Male', 'Female', 'Other'];

/// ---------------------------------------------------------------------------
/// USER PROFILE MODEL
/// The data shown on the Profile / Settings screen. Stored in Firestore at
/// users/{uid} (fullName / email / gender / address / course / university /
/// photoUrl / createdAt).
/// gender, address, course, university and photoUrl are optional and may be
/// empty — older accounts created before these fields existed simply read
/// back as ''.
/// ---------------------------------------------------------------------------
class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String gender;
  final String address;
  final String course;
  final String university;
  final String photoUrl;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.gender = '',
    this.address = '',
    this.course = '',
    this.university = '',
    this.photoUrl = '',
    this.createdAt,
  });

  /// Builds a profile from a Firestore document map.
  ///
  /// Every field falls back to a safe default, so a document that was written
  /// before gender/address existed (or a missing document entirely) never
  /// throws. The fallbacks let the caller fill in FirebaseAuth values.
  factory UserProfile.fromMap(
    Map<String, dynamic>? data, {
    required String uid,
    String fallbackName = '',
    String fallbackEmail = '',
    DateTime? fallbackCreatedAt,
  }) {
    final createdAt = data?['createdAt'];
    return UserProfile(
      uid: uid,
      fullName: _string(data?['fullName'], fallbackName),
      email: _string(data?['email'], fallbackEmail),
      gender: _string(data?['gender'], ''),
      address: _string(data?['address'], ''),
      course: _string(data?['course'], ''),
      university: _string(data?['university'], ''),
      photoUrl: _string(data?['photoUrl'], ''),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : fallbackCreatedAt,
    );
  }

  /// The profile fields as they are stored in Firestore.
  ///
  /// createdAt is deliberately left out: it is written once at registration
  /// with FieldValue.serverTimestamp() and must never be overwritten later.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'gender': gender,
      'address': address,
      'course': course,
      'university': university,
      'photoUrl': photoUrl,
    };
  }

  /// Reads a Firestore value as a String, using [fallback] when it is
  /// missing, null or stored as another type.
  static String _string(dynamic value, String fallback) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
  }

  /// Name to show when the user hasn't set one yet.
  String get displayName =>
      fullName.trim().isEmpty ? 'Student' : fullName.trim();

  /// First name only (used for the dashboard greeting).
  String get firstName => displayName.split(' ').first;

  /// Up to two initials for the default avatar (e.g. "Hari Krishnan" -> "HK").
  String get initials {
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserProfile copyWith({
    String? fullName,
    String? gender,
    String? address,
    String? course,
    String? university,
    String? photoUrl,
  }) {
    return UserProfile(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      course: course ?? this.course,
      university: university ?? this.university,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }
}
