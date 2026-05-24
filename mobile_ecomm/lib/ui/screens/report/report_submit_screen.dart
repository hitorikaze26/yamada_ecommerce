import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/report/report_navigation.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/problem_report_model.dart';
import '../../../data/providers/reports_notifier.dart';

class ReportSubmitScreen extends ConsumerStatefulWidget {
  final ReportSubmitArgs args;

  const ReportSubmitScreen({super.key, required this.args});

  @override
  ConsumerState<ReportSubmitScreen> createState() => _ReportSubmitScreenState();
}

class _ReportSubmitScreenState extends ConsumerState<ReportSubmitScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  int? _selectedTypeId;
  final List<File> _evidenceFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(reportsProvider.notifier)
          .fetchReportTypes(widget.args.targetRole);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Map<String, List<ReportTypeModel>> _groupedTypes(List<ReportTypeModel> types) {
    final map = <String, List<ReportTypeModel>>{};
    for (final t in types) {
      final key = t.category ?? 'other';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  Future<void> _pickEvidence() async {
    if (_evidenceFiles.length >= 5) {
      AlertService.showSnackBar(
        context: context,
        message: 'Maximum 5 images allowed',
        variant: AlertVariant.warning,
      );
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      for (final x in picked) {
        if (_evidenceFiles.length >= 5) break;
        _evidenceFiles.add(File(x.path));
      }
    });
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (_selectedTypeId == null) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please select an issue type',
        variant: AlertVariant.warning,
      );
      return;
    }
    if (description.length < 10) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please enter at least 10 characters',
        variant: AlertVariant.warning,
      );
      return;
    }

    final report = await ref.read(reportsProvider.notifier).submitReport(
          reportTypeId: _selectedTypeId!,
          description: description,
          targetRole: widget.args.targetRole,
          storeId: widget.args.storeId,
          orderId: widget.args.orderId,
          targetUserId: widget.args.targetUserId,
          evidenceFiles: _evidenceFiles,
        );

    if (!mounted) return;

    if (report != null) {
      AlertService.showSnackBar(
        context: context,
        message: 'Report submitted. Our team will review it shortly.',
        variant: AlertVariant.success,
      );
      context.pop(true);
    } else {
      final err = ref.read(reportsProvider).error;
      if (err != null) {
        AlertService.showSnackBar(
          context: context,
          message: err,
          variant: AlertVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
    final foreground = isDark ? AppColors.darkForeground : AppColors.charcoal;
    final primary = theme.colorScheme.primary;
    final grouped = _groupedTypes(state.reportTypes);
    final label = widget.args.contextLabel ??
        (widget.args.orderId != null
            ? 'Order #${widget.args.orderId}'
            : widget.args.storeId != null
                ? 'Store #${widget.args.storeId}'
                : reportTargetRoleLabel(widget.args.targetRole));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: foreground,
        title: const Text('Report a problem'),
      ),
      body: state.isLoadingTypes && state.reportTypes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primary.withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flag_outlined, color: primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reporting: ${reportTargetRoleLabel(widget.args.targetRole)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Issue type',
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                ),
                const SizedBox(height: 8),
                if (state.reportTypes.isEmpty && !state.isLoadingTypes)
                  Text(
                    state.error ?? 'No report types available.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ...grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          reportCategoryLabel(entry.key),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ),
                      ...entry.value.map((type) {
                        return RadioListTile<int>(
                          value: type.id,
                          groupValue: _selectedTypeId,
                          onChanged: state.isSubmitting
                              ? null
                              : (v) => setState(() => _selectedTypeId = v),
                          activeColor: primary,
                          title: Text(
                            type.displayName,
                            style: TextStyle(color: foreground),
                          ),
                          subtitle: type.description != null &&
                                  type.description!.isNotEmpty
                              ? Text(
                                  type.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: muted, fontSize: 12),
                                )
                              : null,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  maxLength: 2000,
                  style: TextStyle(color: foreground),
                  decoration: InputDecoration(
                    hintText: 'Describe what happened in detail…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Evidence (optional)',
                      style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${_evidenceFiles.length}/5',
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._evidenceFiles.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final file = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _evidenceFiles.removeAt(idx)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    if (_evidenceFiles.length < 5)
                      InkWell(
                        onTap: state.isSubmitting ? null : _pickEvidence,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit report'),
                ),
              ],
            ),
    );
  }
}
