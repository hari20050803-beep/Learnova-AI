import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/profile_avatar.dart';

/// ---------------------------------------------------------------------------
/// EDIT PROFILE
/// Change the avatar (gallery), full name, course and university. Saves to
/// Firestore users/{uid}. The avatar is uploaded to Firebase Storage when it
/// is available; otherwise it is kept for this session and will sync later.
/// Returns true via Navigator.pop when the profile changed.
/// ---------------------------------------------------------------------------
class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _courseController;
  late final TextEditingController _universityController;

  /// Image the user just picked (not saved yet).
  Uint8List? _pickedBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _courseController = TextEditingController(text: widget.profile.course);
    _universityController = TextEditingController(
      text: widget.profile.university,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _courseController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _pickedBytes = bytes);
    } catch (_) {
      _showMessage('Could not open that image.');
    }
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter your full name.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Save the text fields.
      await AuthService.instance.updateProfile(
        fullName: name,
        course: _courseController.text.trim(),
        university: _universityController.text.trim(),
      );

      // 2. Save the avatar if a new one was picked.
      if (_pickedBytes != null) {
        try {
          await AuthService.instance.saveAvatar(_pickedBytes!);
        } on AuthException catch (e) {
          // The file could not be written. Keep the photo for this session so
          // the user still sees it, and say what happened.
          AuthService.instance.localAvatarBytes = _pickedBytes;
          _showMessage(e.message, isError: false);
        }
      }

      if (!mounted) return;
      _showMessage('Profile updated.', isError: false);
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? previewBytes =
        _pickedBytes ?? AuthService.instance.localAvatarBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- Avatar with camera badge -----
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ProfileAvatar(
                        radius: 50,
                        initials: widget.profile.initials,
                        bytes: previewBytes,
                        photoUrl: previewBytes == null
                            ? widget.profile.photoUrl
                            : '',
                        // Landing point for the avatar flying in from Profile.
                        heroTag: kProfileAvatarHeroTag,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.mainGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.card(context),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Tap the photo to change it',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subText(context),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ----- Full name (required) -----
              _label('Full name'),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Hari Krishnan',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 18),

              // ----- Course (optional) -----
              _label('Course / Programme  (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _courseController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. BSc Computer Science',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 18),

              // ----- University (optional) -----
              _label('University / Institute  (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _universityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Anna University',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: 30),

              GradientButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.subText(context),
      ),
    );
  }
}
