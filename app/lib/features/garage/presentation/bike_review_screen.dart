import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';
import 'package:motomuse/features/garage/domain/bike_photo_analysis.dart';

/// Displays the AI-extracted bike details and the affirming message.
///
/// The user can correct any inaccuracies in the editable fields, add or
/// remove visible modifications, then confirm to save the bike to Firestore.
class BikeReviewScreen extends ConsumerStatefulWidget {
  /// Creates the bike review screen.
  const BikeReviewScreen({required this.analysis, super.key});

  /// The combined result of the photo upload and Cloud Run analysis.
  final BikePhotoAnalysis analysis;

  @override
  ConsumerState<BikeReviewScreen> createState() => _BikeReviewScreenState();
}

class _BikeReviewScreenState extends ConsumerState<BikeReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _makeCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _trimCtrl;
  late final TextEditingController _addModCtrl;
  late List<String> _modifications;

  @override
  void initState() {
    super.initState();
    final r = widget.analysis.result;
    _makeCtrl = TextEditingController(text: r.make);
    _modelCtrl = TextEditingController(text: r.model);
    _yearCtrl = TextEditingController(text: r.year?.toString() ?? '');
    _colorCtrl = TextEditingController(text: r.color ?? '');
    _trimCtrl = TextEditingController(text: r.trim ?? '');
    _addModCtrl = TextEditingController();
    _modifications = List<String>.from(r.modifications);
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _trimCtrl.dispose();
    _addModCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Navigate to Garage on save success, or show error.
    // Guard: only react when transitioning OUT of AsyncLoading —
    // that means the user explicitly triggered confirm().  The initial
    // synchronous build of ConfirmBikeNotifier emits AsyncData(null)
    // with a null previous value; without this guard that would
    // trigger unwanted navigation on every first render.
    ref.listen<AsyncValue<void>>(
      confirmBikeNotifierProvider,
      (previous, next) {
        if (previous is! AsyncLoading) return;
        next.whenOrNull(
          data: (_) {
            // Reset the add-bike notifier so the flow is fresh next time.
            ref.read(addBikeNotifierProvider.notifier).reset();
            context.go(AppRoutes.garage);
          },
          error: (e, _) {
            final msg = e is BikeException
                ? e.message
                : 'Failed to save your bike. Please try again.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          },
        );
      },
    );

    final confirmState = ref.watch(confirmBikeNotifierProvider);
    final isSaving = confirmState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review your bike'),
        automaticallyImplyLeading: !isSaving,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BikeImageHeader(imageUrl: widget.analysis.imageUrl),
                const SizedBox(height: 20),
                _AffirmingMessageCard(
                  message: widget.analysis.result.affirmingMessage,
                ),
                const SizedBox(height: 28),
                _SectionLabel(label: 'Your details', theme: theme),
                const SizedBox(height: 12),
                _EditField(
                  controller: _makeCtrl,
                  label: 'Make',
                  hint: 'e.g. Ducati',
                  validator: _requiredField,
                ),
                const SizedBox(height: 12),
                _EditField(
                  controller: _modelCtrl,
                  label: 'Model',
                  hint: 'e.g. Panigale V4 S',
                  validator: _requiredField,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _EditField(
                        controller: _yearCtrl,
                        label: 'Year',
                        hint: 'e.g. 2021',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EditField(
                        controller: _colorCtrl,
                        label: 'Colour',
                        hint: 'e.g. Ducati Red',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EditField(
                  controller: _trimCtrl,
                  label: 'Trim / variant',
                  hint: 'e.g. S, Adventure, SP',
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: 'Modifications', theme: theme),
                const SizedBox(height: 8),
                _ModificationsEditor(
                  modifications: _modifications,
                  controller: _addModCtrl,
                  onAdd: _addModification,
                  onRemove: _removeModification,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: isSaving ? null : _confirm,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Looks right — save my bike'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addModification() {
    final text = _addModCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _modifications = [..._modifications, text];
    });
    _addModCtrl.clear();
  }

  void _removeModification(String mod) {
    setState(() {
      _modifications = _modifications.where((m) => m != mod).toList();
    });
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final year = int.tryParse(_yearCtrl.text.trim());
    final bike = Bike(
      id: '', // assigned by Firestore on save
      make: _makeCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: year,
      displacement: widget.analysis.result.displacement,
      color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      trim: _trimCtrl.text.trim().isEmpty ? null : _trimCtrl.text.trim(),
      modifications: _modifications,
      category: widget.analysis.result.category,
      affirmingMessage: widget.analysis.result.affirmingMessage,
      imageUrl: widget.analysis.imageUrl,
      addedAt: DateTime.now(),
    );

    ref.read(confirmBikeNotifierProvider.notifier).confirm(bike);
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _BikeImageHeader extends StatelessWidget {
  const _BikeImageHeader({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: Colors.grey.shade200,
            child: const Icon(Icons.two_wheeler, size: 64, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _AffirmingMessageCard extends StatelessWidget {
  const _AffirmingMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.gold : AppColors.amber;
    final bgColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: borderColor),
              const SizedBox(width: 6),
              Text(
                'Your bike',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: borderColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ModificationsEditor extends StatelessWidget {
  const _ModificationsEditor({
    required this.modifications,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> modifications;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (modifications.isEmpty)
          Text(
            'No modifications identified.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: modifications
                .map(
                  (mod) => Chip(
                    label: Text(mod),
                    onDeleted: () => onRemove(mod),
                    deleteIconColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Add a modification',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Add modification',
            ),
          ],
        ),
      ],
    );
  }
}
