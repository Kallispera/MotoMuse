import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';
import 'package:motomuse/features/garage/domain/bike_photo_analysis.dart';

/// Full-screen flow for adding a new bike: image source selection → upload
/// progress → Cloud Run analysis.
///
/// On successful analysis, navigates automatically to the bike review screen.
/// If the user cancels the picker, returns to the source-selection UI.
class AddBikeScreen extends ConsumerStatefulWidget {
  /// Creates the add-bike screen.
  const AddBikeScreen({super.key});

  @override
  ConsumerState<AddBikeScreen> createState() => _AddBikeScreenState();
}

class _AddBikeScreenState extends ConsumerState<AddBikeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analysisState = ref.watch(addBikeNotifierProvider);

    // Navigate to review when analysis completes, or show error.
    ref.listen<AsyncValue<BikePhotoAnalysis?>>(
      addBikeNotifierProvider,
      (_, next) {
        next.whenOrNull(
          data: (analysis) {
            if (analysis == null) return; // user cancelled picker
            context.push(AppRoutes.bikeReview, extra: analysis);
          },
          error: (e, _) {
            final msg = e is BikeException
                ? e.message
                : 'Something went wrong. Please try again.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
            // Reset so the picker buttons reappear.
            ref.read(addBikeNotifierProvider.notifier).reset();
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a bike'),
        leading: BackButton(
          onPressed: () {
            ref.read(addBikeNotifierProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: analysisState.isLoading
            ? _LoadingBody(theme: theme)
            : _PickerBody(theme: theme),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker body — shown when idle
// ---------------------------------------------------------------------------

class _PickerBody extends ConsumerWidget {
  const _PickerBody({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.two_wheeler_outlined,
            size: 72,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Show us your machine.',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'A single clear photo is all we need to identify your bike'
            ' and tell you something interesting about it.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () => ref
                .read(addBikeNotifierProvider.notifier)
                .pickAndAnalyze(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take a photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(addBikeNotifierProvider.notifier)
                .pickAndAnalyze(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading body — shown during upload + analysis
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Identifying your machine…',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Uploading your photo and consulting our AI expert.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.lightTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
