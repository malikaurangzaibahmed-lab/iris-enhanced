import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';

/// Ultra-Streamlined In-App User Feedback Transceiver for IRIS Mobile Client.
/// Pre-fills ALL user profile details, role, batch, roll number, and hardware telemetry.
/// ASKS THE USER ONLY FOR THEIR FEEDBACK NOTE.
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

  @override
  void initState() {
    super.initState();
    _autoPrefillAllTelemetryData();
  }

  void _autoPrefillAllTelemetryData() async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-detect real user name
    final name = prefs.getString('student_user_name')?.trim().isNotEmpty == true
        ? prefs.getString('student_user_name')!.trim()
        : (prefs.getString('student_name') ??
           prefs.getString('user_name') ??
           prefs.getString('name') ??
           'IRIS Student');

    // Auto-detect real batch / class
    final batch = prefs.getString('student_batch') ??
                  prefs.getString('current_batch') ??
                  prefs.getString('user_batch') ??
                  prefs.getString('selected_batch') ??
                  'SP26-BCS-1-A';

    // Auto-detect real roll number / ID
    final roll = prefs.getString('student_roll_no') ??
                 prefs.getString('roll_no') ??
                 prefs.getString('student_id') ??
                 prefs.getString('roll_number') ??
                 'SP26-BCS-001';

    // Auto-detect role
    final savedRole = (prefs.getString('active_role') ?? prefs.getString('user_role') ?? prefs.getString('role') ?? '').toLowerCase();
    String detectedRole = 'Student';
    if (savedRole.contains('faculty') || savedRole.contains('teacher') || savedRole.contains('instructor') || savedRole.contains('prof')) {
      detectedRole = 'Faculty';
    }

    // Auto-detect device hardware specs
    String specs = 'REALME RMX3840 • Android 15 (SDK 35)';
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
    final textColor = effectiveIsDark ? Colors.white : Colors.black;
    final mutedTextColor = (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.6);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        elevation: 0,
        leading: AppBackButton(
          isDark: effectiveIsDark,
          onPressed: widget.onBackPressed,
        ),
      ),
      backgroundColor: Colors.transparent,
      body: SafeArea(
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
                      color: IrisTokens.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: IrisTokens.brand.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.rate_review_rounded, color: IrisTokens.brand, size: 26),
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
                          color: textColor,
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
                              Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _userRole == 'Faculty'
                                      ? Colors.purple.withValues(alpha: 0.2)
                                      : IrisTokens.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _userRole.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: _userRole == 'Faculty' ? Colors.purpleAccent : IrisTokens.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
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
                      Icons.check_circle_rounded,
                      size: 18,
                      color: IrisTokens.brand,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 5-Star Rating Bar
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Text(
                      'RATE YOUR EXPERIENCE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
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
                          iconSize: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isFilled ? Colors.amber : mutedTextColor,
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
              const SizedBox(height: 18),

              // THE ONLY INPUT FIELD: Feedback / Suggestions Text
              Text(
                'YOUR FEEDBACK / SUGGESTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your feedback, bug report, or feature request here...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: mutedTextColor.withValues(alpha: 0.5),
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
                    elevation: 8,
                    shadowColor: IrisTokens.brand.withValues(alpha: 0.4),
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
    );
  }
}
