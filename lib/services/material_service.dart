import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../models/study_material.dart';

/// Thrown by [MaterialService] with a message safe to show to the user.
class MaterialException implements Exception {
  final String message;

  MaterialException(this.message);

  @override
  String toString() => message;
}

/// Count + most recent material, for the main Dashboard.
class MaterialSummary {
  final int total;
  final StudyMaterial? recent;

  const MaterialSummary({required this.total, required this.recent});
}

/// ---------------------------------------------------------------------------
/// MATERIAL SERVICE
/// Firestore metadata at users/{uid}/study_materials/{materialId}, and the
/// files themselves in the application's own private directory on the device:
///   `<app documents>/study_materials/{uid}/{timestamp_filename}`
///
/// The files were originally put in Firebase Storage. Cloud Storage now
/// requires the paid Blaze plan, which this project does not have, so every
/// upload failed and the module could not be used at all. Keeping the bytes on
/// the device makes the module work on the free plan, removes the network from
/// the read path — "Summarize with AI" no longer has to download the file
/// first — and keeps a student's material off a third-party server. The cost
/// is that the files do not follow the account to another device; that is
/// recorded as a limitation rather than hidden.
///
/// The [StudyMaterial.storagePath] field carries the absolute path of the file
/// on the device. Records written before this change hold a Firebase Storage
/// path there and an https URL in [StudyMaterial.fileUrl]; those still open in
/// the browser, so nothing already saved is lost.
/// ---------------------------------------------------------------------------
class MaterialService {
  MaterialService._();

  static final MaterialService instance = MaterialService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw MaterialException('You are not logged in. Please login again.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _materials() =>
      _db.collection('users').doc(_uid).collection('study_materials');

  /// Loads all materials of the current user, newest first.
  Future<List<StudyMaterial>> loadMaterials() async {
    try {
      final snapshot = await _materials()
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(StudyMaterial.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw MaterialException('Could not load materials: ${e.message}');
    }
  }

  /// The per-account folder that holds the saved files.
  ///
  /// Keyed by uid so two accounts used on one device cannot read each other's
  /// material, and created on first use.
  Future<Directory> _fileDir() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}study_materials'
      '${Platform.pathSeparator}$_uid',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Strips anything that cannot safely appear in a file name.
  ///
  /// The name comes from a file the student chose, so it can contain path
  /// separators or characters the platform rejects. A timestamp is prefixed so
  /// that saving the same file twice does not overwrite the first copy.
  String _safeName(String fileName) {
    final String cleaned = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final String name = cleaned.isEmpty ? 'material' : cleaned;
    return '${DateTime.now().millisecondsSinceEpoch}_$name';
  }

  /// Writes the picked file into the application's own directory and returns
  /// its absolute path.
  Future<String> _saveFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final Directory dir = await _fileDir();
      final File file = File(
        '${dir.path}${Platform.pathSeparator}${_safeName(fileName)}',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on FileSystemException catch (e) {
      throw MaterialException(
        'Could not save the file on this device: ${e.message}',
      );
    }
  }

  /// Adds a new material. If [fileBytes] is given, the file is written to the
  /// device first; otherwise this is a link-only material.
  Future<StudyMaterial> addMaterial(
    StudyMaterial material, {
    Uint8List? fileBytes,
    String? contentType,
  }) async {
    String fileUrl = material.fileUrl;
    String storagePath = material.storagePath;

    if (fileBytes != null) {
      storagePath = await _saveFile(
        bytes: fileBytes,
        fileName: material.fileName,
      );
      // No download URL exists for a file held on the device; the path is the
      // handle, and [StudyMaterial.isDeviceFile] reads it.
      fileUrl = '';
    }

    try {
      final toSave = material.copyWith(
        fileUrl: fileUrl,
        storagePath: storagePath,
      );
      final ref = await _materials().add(toSave.toMap());
      return toSave.copyWith(id: ref.id);
    } on FirebaseException catch (e) {
      throw MaterialException('Could not save the material: ${e.message}');
    }
  }

  /// Updates the editable metadata of a material (not the file itself).
  Future<void> updateMaterial(StudyMaterial material) async {
    try {
      await _materials().doc(material.id).update({
        'title': material.title,
        'subject': material.subject,
        'category': material.category,
        'description': material.description,
        'linkUrl': material.linkUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException catch (e) {
      throw MaterialException('Could not update the material: ${e.message}');
    }
  }

  Future<void> setFavorite(StudyMaterial material, bool isFavorite) async {
    try {
      await _materials().doc(material.id).update({'isFavorite': isFavorite});
    } on FirebaseException catch (e) {
      throw MaterialException('Could not update favorite: ${e.message}');
    }
  }

  /// Saves an AI-generated summary onto the material record (#9).
  Future<void> saveSummary(String id, String summary) async {
    try {
      await _materials().doc(id).update({'summary': summary});
    } on FirebaseException catch (e) {
      throw MaterialException('Could not save the summary: ${e.message}');
    }
  }

  /// Deletes a material: its file on the device (if any) and its Firestore doc.
  Future<void> deleteMaterial(StudyMaterial material) async {
    // Delete the file first; ignore if it is already gone.
    if (material.isDeviceFile) {
      try {
        final File file = File(material.storagePath);
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (_) {
        // File may not exist anymore — keep going and delete the metadata.
      }
    }
    try {
      await _materials().doc(material.id).delete();
    } on FirebaseException catch (e) {
      throw MaterialException('Could not delete the material: ${e.message}');
    }
  }

  /// Reads a material's bytes back off the device (used by "Summarize with
  /// AI"). No network is involved, so this works offline.
  Future<Uint8List> fetchBytes(StudyMaterial material) async {
    if (material.storagePath.isEmpty) {
      throw MaterialException('This material has no file to read.');
    }
    try {
      final File file = File(material.storagePath);
      if (!await file.exists()) {
        throw MaterialException(
          'The file is no longer on this device. It may have been removed '
          'when the app was uninstalled or its data was cleared.',
        );
      }
      return await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw MaterialException('Could not read the file: ${e.message}');
    }
  }

  /// Count + most recent material for the main Dashboard (#10).
  Future<MaterialSummary> loadSummary() async {
    try {
      final countSnap = await _materials().count().get();
      final recentSnap = await _materials()
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      return MaterialSummary(
        total: countSnap.count ?? 0,
        recent: recentSnap.docs.isEmpty
            ? null
            : StudyMaterial.fromDoc(recentSnap.docs.first),
      );
    } on FirebaseException catch (e) {
      throw MaterialException('Could not load materials: ${e.message}');
    }
  }
}
