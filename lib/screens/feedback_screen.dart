import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../core/vital_theme.dart';

/// Ultra-Streamlined In-App User Feedback Transceiver for IRIS Mobile Client.
/// Pre-fills user profile details, role, batch, roll number, and hardware telemetry.
class FeedbackScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final bool? isDark;

  const FeedbackScreen({
    super.key,
    this.onBackPressed,
    this.isDark,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _commentController = TextEditingController();

  String _userRole = 'Student';
  String _userName = 'IRIS Student';
  String _userBatch = 'SP26-BCS-1-A';
  String _rollNumber = 'SP26-BCS-001';
  String _deviceSpecs = 'Detecting device telemetry...';
  String _category = 'General Feedback';
  int _selectedRating = 5;
  bool _isSubmitting = false;

  static const List<String> _categories = [
    'General Feedback',
    'Bug Report',
    'Feature Request',
    'Timetable Issue',
    'UI & Theme',
  ];

  @override
  void initState() {
    super.initState();
    _autoPrefillAllTelemetryData();
  }

  void _autoPrefillAllTelemetryData() async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-detect role
    final savedRole = (prefs.getString('active_role') ?? prefs.getString('user_role') ?? prefs.getString('role') ?? '').toLowerCase();
    String detectedRole = 'Student';
    if (savedRole.contains('faculty') || savedRole.contains('teacher') || savedRole.contains('instructor') || savedRole.contains('prof')) {
      detectedRole = 'Faculty';
    }

    String name = 'IRIS Mobile User';
    String batch = 'SP26-BCS-1-A';
    String roll = 'SP26-BCS-001';

    if (detectedRole == 'Faculty') {
      name = prefs.getString('faculty_user_name') ??
             prefs.getString('faculty_teacher') ??
             prefs.getString('student_name') ??
             prefs.getString('user_name') ??
             prefs.getString('name') ??
             'Faculty Member';

      batch = prefs.getString('faculty_department') ??
              prefs.getString('department') ??
              prefs.getString('faculty_dept') ??
              'COMSATS Faculty';

      roll = prefs.getString('faculty_id') ??
             prefs.getString('employee_id') ??
             prefs.getString('faculty_emp_id') ??
             'FACULTY-ID';
    } else {
      name = prefs.getString('student_user_name')?.trim().isNotEmpty == true
          ? prefs.getString('student_user_name')!.trim()
          : (prefs.getString('student_name') ??
             prefs.getString('user_name') ??
             prefs.getString('name') ??
             'IRIS Student');

      batch = prefs.getString('student_batch') ??
                    prefs.getString('current_batch') ??
                    prefs.getString('user_batch') ??
                    prefs.getString('selected_batch') ??
                    'SP26-BCS-1-A';

      roll = prefs.getString('student_roll_no') ??
                    prefs.getString('roll_no') ??
                    prefs.getString('student_id') ??
                    prefs.getString('roll_number') ??
                    'SP26-BCS-001';
    }

    // Auto-detect device hardware specs
    String specs = 'Android Device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toUpperCase();
      final model = androidInfo.model;
      final release = androidInfo.version.release;
      final sdk = androidInfo.version.sdkInt;
      specs = '$manufacturer $model • Android $release (SDK $sdk)';
    } catch (_) {}

    if (mounted) {
      setState(() {
        _userRole = detectedRole;
        _userName = name;
        _userBatch = batch;
        _rollNumber = roll;
        _deviceSpecs = specs;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitFeedback() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      IrisHaptics.actionMedium();
      showIrisFrostedSnackBar(
        context,
        content: const Text('Please type your feedback or suggestion before sending.'),
        tint: Colors.amber,
      );
      return;
    }

    IrisHaptics.actionHeavy();
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'name': _userName,
        'user_role': _userRole,
        'roll_number': _rollNumber,
        'batch': _userBatch,
        'device': _deviceSpecs,
        'category': _category,
        'rating': _selectedRating,
        'comment': comment,
        'created_at': FieldValue.serverTimestamp(),
        'platform': 'Android Mobile Client',
      });

      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: const Text(
            '✅ Feedback transmitted live to Admin Console!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          tint: IrisTokens.brand,
        );
        _commentController.clear();
        setState(() => _selectedRating = 5);
      }
    } catch (e) {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: Text('Failed to submit feedback: $e'),
          tint: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final textColor = effectiveIsDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = effectiveIsDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: effectiveIsDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(
          isDark: effectiveIsDark,
          onPressed: widget.onBackPressed,
        ),
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: effectiveIsDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: IrisTokens.brandGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Feedback',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Share your thoughts with the IRIS team',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Auto-Prefilled Telemetry Identity Badge
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: IrisTokens.brand.withValues(alpha: 0.2),
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: IrisTokens.brand,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _userName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _userRole == 'Faculty'
                                          ? (effectiveIsDark ? Colors.purple.withValues(alpha: 0.25) : const Color(0xFFF3E8FF))
                                          : IrisTokens.brand.withValues(alpha: effectiveIsDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _userRole == 'Faculty'
                                            ? Colors.purple.withValues(alpha: 0.4)
                                            : IrisTokens.brand.withValues(alpha: 0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      _userRole.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: _userRole == 'Faculty'
                                            ? (effectiveIsDark ? Colors.purpleAccent : const Color(0xFF7C3AED))
                                            : IrisTokens.brand,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$_userBatch • $_deviceSpecs',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: mutedTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: IrisTokens.brand,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category Selector
                  Text(
                    'FEEDBACK CATEGORY',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: IrisTokens.brand,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = cat == _category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              IrisHaptics.chipSelect();
                              setState(() => _category = cat);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? IrisTokens.brand.withValues(alpha: effectiveIsDark ? 0.22 : 0.14)
                                    : (effectiveIsDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? IrisTokens.brand
                                      : (effectiveIsDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? IrisTokens.brand
                                      : (effectiveIsDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5-Star Rating Bar
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'RATE YOUR EXPERIENCE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: IrisTokens.brand,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starRating = index + 1;
                            final isFilled = starRating <= _selectedRating;
                            return IconButton(
                              iconSize: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              icon: Icon(
                                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: isFilled ? const Color(0xFFF59E0B) : (effectiveIsDark ? Colors.white24 : Colors.black26),
                              ),
                              onPressed: () {
                                IrisHaptics.selectionClick();
                                setState(() => _selectedRating = starRating);
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Feedback / Suggestions Text Field
                  Text(
                    'YOUR FEEDBACK / SUGGESTION',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: IrisTokens.brand,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(4),
                    child: TextFormField(
                      controller: _commentController,
                      maxLines: 5,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your feedback, bug report, or feature request here...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: mutedTextColor.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Glowing Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: IrisTokens.brand.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'TRANSMITTING...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'TRANSMIT FEEDBACK TO ADMIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
