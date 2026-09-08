import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories a study material can belong to.
const List<String> kMaterialCategories = [
  'Lecture Note',
  'Assignment Guide',
  'Exam Paper',
  'Tutorial',
  'Reference',
  'Other',
];

/// ---------------------------------------------------------------------------
/// STUDY MATERIAL (one uploaded file or saved link) in Firestore:
///   users/{uid}/study_materials/{materialId}
/// ---------------------------------------------------------------------------
class StudyMaterial {
  final String id;
  final String title;
  final String subject;
  final String category;
  final String description;
  final String fileName;
  final String fileUrl; // https URL of an older cloud-stored file, else ''
  final String fileType; // 'pdf' | 'image' | 'doc' | 'link'
  final String linkUrl; // for link materials, else ''
  final String storagePath; // absolute path of the file on this device
  final String summary; // AI-generated summary (#9), else ''
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyMaterial({
    required this.id,
    required this.title,
    required this.subject,
    required this.category,
    required this.description,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.linkUrl,
    required this.storagePath,
    required this.summary,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when there is an actual file (not just a link), wherever it is held.
  bool get hasFile => storagePath.isNotEmpty || fileUrl.isNotEmpty;

  /// True when the file lives in the application's own directory on this
  /// device, which is where every file saved since the seventh session goes.
  /// Older records carry a cloud URL instead and are opened in the browser.
  bool get isDeviceFile => storagePath.isNotEmpty && fileUrl.isEmpty;

  /// True when AI can read this material (PDF or image only).
  bool get canSummarize =>
      hasFile && (fileType == 'pdf' || fileType == 'image');

  /// What the user opens when tapping "view/open". Empty for a file on the
  /// device — that one is opened by path, not by URL.
  String get openUrl => fileType == 'link' ? linkUrl : fileUrl;

  factory StudyMaterial.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return StudyMaterial(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      subject: (data['subject'] ?? '') as String,
      category: (data['category'] ?? 'Other') as String,
      description: (data['description'] ?? '') as String,
      fileName: (data['fileName'] ?? '') as String,
      fileUrl: (data['fileUrl'] ?? '') as String,
      fileType: (data['fileType'] ?? 'link') as String,
      linkUrl: (data['linkUrl'] ?? '') as String,
      storagePath: (data['storagePath'] ?? '') as String,
      summary: (data['summary'] ?? '') as String,
      isFavorite: (data['isFavorite'] ?? false) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'subject': subject,
    'category': category,
    'description': description,
    'fileName': fileName,
    'fileUrl': fileUrl,
    'fileType': fileType,
    'linkUrl': linkUrl,
    'storagePath': storagePath,
    'summary': summary,
    'isFavorite': isFavorite,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  StudyMaterial copyWith({
    String? id,
    String? title,
    String? subject,
    String? category,
    String? description,
    String? fileName,
    String? fileUrl,
    String? fileType,
    String? linkUrl,
    String? storagePath,
    String? summary,
    bool? isFavorite,
    DateTime? updatedAt,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      linkUrl: linkUrl ?? this.linkUrl,
      storagePath: storagePath ?? this.storagePath,
      summary: summary ?? this.summary,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
