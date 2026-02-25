import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/explore/application/explore_providers.dart';
import 'package:motomuse/features/onboarding/application/onboarding_providers.dart';
import 'package:motomuse/features/onboarding/domain/closest_region_calculator.dart';
import 'package:motomuse/features/profile/domain/user_profile.dart';

/// Profile screen — account info, rider profile, and sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _addressController = TextEditingController();
  bool _isEditingAddress = false;
  bool _isSavingAddress = false;
  String? _addressError;

  // Local riding preference state — synced from profile on first build.
  int _curviness = 3;
  String _sceneryType = 'mixed';
  int _distanceKm = 150;
  bool _prefsInitialized = false;
  bool _isSavingPrefs = false;
  bool _prefsChanged = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;

    // Sync local preference state from Firestore once.
    if (!_prefsInitialized && profile != null) {
      _curviness = profile.defaultCurviness ?? 3;
      _sceneryType = profile.defaultSceneryType ?? 'mixed';
      _distanceKm = profile.defaultDistanceKm ?? 150;
      _prefsInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // ── Account ──
          _buildUserInfoCard(theme, user),
          const SizedBox(height: 28),

          // ── Rider Profile ──
          const _SectionHeader(icon: Icons.two_wheeler, label: 'Rider profile'),
          const SizedBox(height: 16),
          _buildHomeAddressArea(theme, profile),
          const SizedBox(height: 24),
          _buildRidingPreferences(theme),
          const SizedBox(height: 32),

          // ── Sign out ──
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account card
  // ---------------------------------------------------------------------------

  Widget _buildUserInfoCard(ThemeData theme, AppUser? user) {
    final displayName = user?.displayName;
    final email = user?.email ?? '';
    final photoUrl = user?.photoUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName != null && displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Home address area
  // ---------------------------------------------------------------------------

  Widget _buildHomeAddressArea(ThemeData theme, UserProfile? profile) {
    final homeAddress = profile?.homeAddress;
    final affirmingMessage = profile?.homeAffirmingMessage;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.gold : AppColors.amber;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Home address',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (homeAddress != null && !_isEditingAddress)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () {
                      _addressController.text = homeAddress;
                      setState(() => _isEditingAddress = true);
                    },
                    tooltip: 'Edit address',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isEditingAddress || homeAddress == null)
              _buildAddressEditForm(theme)
            else ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      homeAddress,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (affirmingMessage != null &&
                  affirmingMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    affirmingMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressEditForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            hintText: 'Enter your home address',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.location_on_outlined),
            errorText: _addressError,
            isDense: true,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveAddress(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _isSavingAddress ? null : _saveAddress,
                child: _isSavingAddress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
            if (ref.read(userProfileProvider).valueOrNull?.homeAddress !=
                null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isSavingAddress
                    ? null
                    : () {
                        setState(() {
                          _isEditingAddress = false;
                          _addressError = null;
                        });
                      },
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Riding preferences
  // ---------------------------------------------------------------------------

  Widget _buildRidingPreferences(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.gold : AppColors.amber;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Riding preferences',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Curviness.
            Text(
              'Curviness',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() {
                    _curviness = star;
                    _prefsChanged = true;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      star <= _curviness
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 32,
                      color: star <= _curviness
                          ? activeColor
                          : theme.colorScheme.outline,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Scenery.
            Text(
              'Scenery',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sceneryOptions.map((opt) {
                final (key, icon, label) = opt;
                final selected = _sceneryType == key;
                return FilterChip(
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _sceneryType = key;
                    _prefsChanged = true;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Distance.
            Text(
              'Default distance',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text('30', style: theme.textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    value: _distanceKm.toDouble(),
                    min: 30,
                    max: 300,
                    divisions: 54,
                    label: '$_distanceKm km',
                    onChanged: (v) => setState(() {
                      _distanceKm = v.round();
                      _prefsChanged = true;
                    }),
                  ),
                ),
                Text('300', style: theme.textTheme.bodySmall),
              ],
            ),
            Center(
              child: Text(
                '$_distanceKm km',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Save button — only visible when preferences have changed.
            if (_prefsChanged) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _isSavingPrefs ? null : _saveRidingPreferences,
                  child: _isSavingPrefs
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save preferences'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _sceneryOptions = [
    ('forests', Icons.forest_outlined, 'Forests'),
    ('coastline', Icons.water_outlined, 'Coast'),
    ('mountains', Icons.terrain_outlined, 'Mountains'),
    ('mixed', Icons.landscape_outlined, 'Mixed'),
  ];

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _saveAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _addressError = 'Please enter an address');
      return;
    }

    setState(() {
      _isSavingAddress = true;
      _addressError = null;
    });

    try {
      final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Not signed in.');

      final geocodingService = ref.read(geocodingServiceProvider);
      final geocoded = await geocodingService.geocodeAddress(address);

      final profileRepo = ref.read(userProfileRepositoryProvider);
      await profileRepo.updateHomeAddress(
        uid: uid,
        homeAddress: geocoded.formattedAddress,
        homeLocation: LatLng(geocoded.lat, geocoded.lng),
      );

      final locations =
          ref.read(ridingLocationsProvider).valueOrNull ?? [];
      final closest = findClosestRegion(
        LatLng(geocoded.lat, geocoded.lng),
        locations,
      );

      if (closest != null) {
        final affirmingMsg = await geocodingService.homeAffirmingMessage(
          address: geocoded.formattedAddress,
          closestRegion: closest.name,
        );
        if (affirmingMsg.isNotEmpty) {
          await profileRepo.updateHomeAffirmingMessage(
            uid: uid,
            message: affirmingMsg,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isEditingAddress = false;
        _isSavingAddress = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _addressError =
            e.toString().replaceFirst('Exception: ', '');
        _isSavingAddress = false;
      });
    }
  }

  Future<void> _saveRidingPreferences() async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() => _isSavingPrefs = true);

    try {
      await ref.read(userProfileRepositoryProvider).updateRidingPreferences(
            uid: uid,
            curviness: _curviness,
            sceneryType: _sceneryType,
            distanceKm: _distanceKm,
          );

      if (!mounted) return;
      setState(() {
        _isSavingPrefs = false;
        _prefsChanged = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Riding preferences saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on Exception {
      if (!mounted) return;
      setState(() => _isSavingPrefs = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
