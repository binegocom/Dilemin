import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/palette.dart';
import '../photos/private_avatar.dart';

/// Shared discovery card; reads only real, backend-authorized profile data.
class OnlineProfileCard extends StatelessWidget {
  const OnlineProfileCard({
    required this.api,
    required this.person,
    required this.onTap,
    super.key,
  });

  final ApiClient api;
  final OnlinePerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: '${person.name}, ${l10n.onlineStatus}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.border.withValues(alpha: .85)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF292137),
                Palette.surface,
                Color(0xFF121525),
              ],
            ),
          ),
          child: InkWell(
            key: ValueKey('online-profile-${person.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: LayoutBuilder(builder: (context, constraints) {
              final tall = constraints.maxHeight >= 155;
              final avatarSize = tall ? 64.0 : 49.0;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: tall ? 10 : 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PrivateAvatar(
                      api: api,
                      userId: person.id,
                      name: person.name,
                      photoId: person.photoId,
                      size: avatarSize,
                      isOnline: true,
                    ),
                    SizedBox(height: tall ? 12 : 7),
                    Text(
                      person.name,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tall ? 14 : 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.15,
                      ),
                    ),
                    if (tall) ...[
                      const SizedBox(height: 5),
                      Text(
                        l10n.onlineStatus,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Palette.mint,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
