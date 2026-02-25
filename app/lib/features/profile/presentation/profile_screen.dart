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

/// Profile screen — user account info, home address, and sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _addressController = TextEditingController();
  bool _isEditingAddress = false;
  bool _isLoading = false;
  String? _error;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // ── User info card ──
          _buildUserInfoCard(theme, user),
          const SizedBox(height: 24),

          // ── Home address section ──
          _buildHomeAddressSection(theme, profile),
          const SizedBox(height: 32),

          // ── Sign out ──
          OutlinedButton.icon(
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // User info card
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
  // Home address section
  // ---------------------------------------------------------------------------

  Widget _buildHomeAddressSection(ThemeData theme, UserProfile? profile) {
    final homeAddress = profile?.homeAddress;
    final affirmingMessage = profile?.homeAffirmingMessage;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.gold : AppColors.amber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header.
        Row(
          children: [
            Icon(
              Icons.home_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Home address',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isEditingAddress || homeAddress == null)
          // ── Edit mode ──
          _buildAddressEditForm(theme)
        else ...[
          // ── Display mode ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          homeAddress,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  // Affirming message.
                  if (affirmingMessage != null &&
                      affirmingMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              _addressController.text = homeAddress;
              setState(() => _isEditingAddress = true);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Update address'),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Address edit form
  // ---------------------------------------------------------------------------

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
            errorText: _error,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveAddress(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _saveAddress,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save address'),
              ),
            ),
            // Only show cancel when an address is already saved.
            if (ref.read(userProfileProvider).valueOrNull?.homeAddress !=
                null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isEditingAddress = false;
                          _error = null;
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
  // Save address action
  // ---------------------------------------------------------------------------

  Future<void> _saveAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter an address');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Not signed in.');

      // 1. Geocode the address.
      final geocodingService = ref.read(geocodingServiceProvider);
      final geocoded = await geocodingService.geocodeAddress(address);

      // 2. Save to Firestore.
      final profileRepo = ref.read(userProfileRepositoryProvider);
      await profileRepo.updateHomeAddress(
        uid: uid,
        homeAddress: geocoded.formattedAddress,
        homeLocation: LatLng(geocoded.lat, geocoded.lng),
      );

      // 3. Find closest region.
      final locations =
          ref.read(ridingLocationsProvider).valueOrNull ?? [];
      final closest = findClosestRegion(
        LatLng(geocoded.lat, geocoded.lng),
        locations,
      );

      // 4. Generate affirming message.
      if (closest != null) {
        final affirmingMsg = await geocodingService.homeAffirmingMessage(
          address: geocoded.formattedAddress,
          closestRegion: closest.name,
        );

        // 5. Save affirming message permanently.
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
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }
}
