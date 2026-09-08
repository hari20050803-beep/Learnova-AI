import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Hero tag shared by the Profile avatar and the Edit Profile avatar, so the
/// portrait flies between them.
///
/// Only used on those two screens: they are connected by a real
/// Navigator.push. The Home avatar deliberately does NOT use it — the tabs
/// live in an IndexedStack, and switching tabs is not a route transition, so
/// a Hero there would never fire.
const String kProfileAvatarHeroTag = 'profile-avatar-hero';

/// ---------------------------------------------------------------------------
/// PROFILE AVATAR
/// Circular avatar with the Learnova gradient ring. Shows, in order of
/// preference: freshly picked image [bytes], a cloud [photoUrl], otherwise
/// the user's [initials] on a soft gradient background.
///
/// Set [heroTag] to animate it across a route push.
/// ---------------------------------------------------------------------------
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final String initials;
  final Uint8List? bytes;
  final String photoUrl;
  final Object? heroTag;

  const ProfileAvatar({
    super.key,
    required this.radius,
    required this.initials,
    this.bytes,
    this.photoUrl = '',
    this.heroTag,
  });

  ImageProvider? get _image {
    if (bytes != null) return MemoryImage(bytes!);
    if (photoUrl.isNotEmpty) return NetworkImage(photoUrl);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = _image;
    final Widget avatar = Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.card(context),
        backgroundImage: image,
        child: image == null
            ? Text(
                initials,
                style: TextStyle(
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.bold,
                  // The circle is filled with the theme's card colour, so raw
                  // indigo initials sit almost invisibly on dark navy.
                  color: AppColors.readable(context, AppColors.indigo),
                ),
              )
            : null,
      ),
    );

    if (heroTag == null) return avatar;

    // The initials shrink with the radius during flight, so the text is given
    // its own Material to avoid the default yellow-underline debug styling.
    return Hero(
      tag: heroTag!,
      flightShuttleBuilder:
          (context, animation, direction, fromContext, toContext) =>
              Material(color: Colors.transparent, child: avatar),
      child: avatar,
    );
  }
}
