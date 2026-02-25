import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/explore/application/explore_providers.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';
import 'package:motomuse/features/onboarding/application/onboarding_providers.dart';
import 'package:motomuse/features/onboarding/domain/closest_region_calculator.dart';

/// Captures the rider's home address after their first bike addition.
///
/// Shows the closest riding region with an affirming message, then
/// transitions to the garage.
class HomeAddressScreen extends ConsumerStatefulWidget {
  /// Creates the home address onboarding screen.
  const HomeAddressScreen({super.key});

  @override
  ConsumerState<HomeAddressScreen> createState() => _HomeAddressScreenState();
}

class _HomeAddressScreenState extends ConsumerState<HomeAddressScreen> {
  final _addressController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // State 2 — results after geocoding.
  RidingLocation? _closestRegion;
  String _affirmingMessage = '';

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home base'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _closestRegion != null
            ? _buildResultState(theme)
            : _buildInputState(theme),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // State 1 — Address input
  // ---------------------------------------------------------------------------

  Widget _buildInputState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.home_outlined,
            size: 72,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Where do you ride from?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "We'll find the best riding areas near you.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Enter your home address',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on_outlined),
              errorText: _error,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _findMyRides(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _findMyRides,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Find my rides'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : _skip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // State 2 — Closest region result
  // ---------------------------------------------------------------------------

  Widget _buildResultState(ThemeData theme) {
    final region = _closestRegion!;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.gold : AppColors.amber;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Affirming message banner.
          if (_affirmingMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: accentColor, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.celebration_outlined,
                          size: 16, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Great news',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _affirmingMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Region summary card.
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Region photo.
                if (region.photoUrls.isNotEmpty)
                  SizedBox(
                    height: 160,
                    child: Image.network(
                      region.photoUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child:
                            const Icon(Icons.landscape, size: 48),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (region.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: region.tags
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        region.description,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons.
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRoutes.locationDetail,
              extra: region,
            ),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explore this area'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _continueToGarage,
            child: const Text('Continue to your garage'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _findMyRides() async {
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
      var affirmingMsg = '';
      if (closest != null) {
        affirmingMsg = await geocodingService.homeAffirmingMessage(
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
        _closestRegion = closest;
        _affirmingMessage = affirmingMsg;
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

  Future<void> _skip() async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid != null) {
      await ref
          .read(userProfileRepositoryProvider)
          .markOnboardingComplete(uid);
    }
    if (mounted) context.go(AppRoutes.garage);
  }

  Future<void> _continueToGarage() async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid != null) {
      await ref
          .read(userProfileRepositoryProvider)
          .markOnboardingComplete(uid);
    }
    if (mounted) context.go(AppRoutes.garage);
  }
}
