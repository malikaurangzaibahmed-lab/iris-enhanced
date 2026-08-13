import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';

/// Ultra-Premium In-App User Feedback & Telemetry Screen for IRIS Mobile Client.
/// Auto-captures student/faculty profile credentials, exact hardware telemetry,
/// and provides zero-friction single-tap feedback submission directly to Firestore.
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

  String _userRole = 'Student'; // 'Student' or 'Faculty'
  String _userName = 'IRIS Mobile User';
  String _userBatch = 'SP26-BCS';
  String _rollNumber = 'IRIS-USER';
  String _deviceSpecs = 'Detecting hardware telemetry...';

  String _selectedCategory = 'General Feedback';
  int _selectedRating = 5;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'General Feedback', 'icon': Icons.chat_bubble_outline_rounded},
    {'name': 'Feature Request', 'icon': Icons.auto_awesome_rounded},
    {'name': 'Bug Report', 'icon': Icons.bug_report_rounded},
    {'name': 'UI/UX Polish', 'icon': Icons.palette_rounded},
    {'name': 'Timetable Correction', 'icon': Icons.edit_calendar_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadTelemetryData();
  }

  void _loadTelemetryData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Auto-detect user name
    final name = prefs.getString('user_name') ?? 
                 prefs.getString('student_name') ?? 
                 prefs.getString('name') ?? 
                 'IRIS Student';
                 
    // Auto-detect batch/class
    final batch = prefs.getString('user_batch') ?? 
                  prefs.getString('student_batch') ?? 
                  prefs.getString('selected_batch') ?? 
                  'SP26-BCS-1-A';
                  
    // Auto-detect roll number / ID
    final roll = prefs.getString('roll_number') ?? 
                 prefs.getString('student_id') ?? 
                 prefs.getString('roll_no') ?? 
                 'REG-${batch.replaceAll('-', '')}';

    // Auto-detect role
    final savedRole = (prefs.getString('user_role') ?? prefs.getString('role') ?? '').toLowerCase();
    String detectedRole = 'Student';
    if (savedRole.contains('faculty') || savedRole.contains('teacher') || savedRole.contains('instructor') || savedRole.contains('prof')) {
      detectedRole = 'Faculty';
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
    } catch (_) {
      specs = 'REALME RMX3840 • Android 15 (SDK 35)';
    }

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
        content: const Text('Please type a quick note or suggestion before sending.'),
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
        'category': _selectedCategory,
        'rating': _selectedRating,
        'comment': comment,
        'created_at': FieldValue.serverTimestamp(),
        'platform': 'Android Mobile Client',
      });

      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: Text(
            '✅ Feedback sent directly to Admin Console! Thank you.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          tint: IrisTokens.brand,
        );
        _commentController.clear();
        setState(() {
          _selectedRating = 5;
          _selectedCategory = 'General Feedback';
        });
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
              // Header Badge
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
                          'Direct feedback transceiver to Admin Console',
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

              // Auto-Identified User Telemetry Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: IrisTokens.brand,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AUTO-IDENTIFIED TELEMETRY PROFILE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: IrisTokens.brand,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _userRole == 'Faculty'
                                ? Colors.purple.withValues(alpha: 0.2)
                                : IrisTokens.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _userRole == 'Faculty' ? Colors.purpleAccent : IrisTokens.brand,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _userRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: _userRole == 'Faculty' ? Colors.purpleAccent : IrisTokens.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: IrisTokens.brand.withValues(alpha: 0.2),
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                '$_userBatch • $_rollNumber',
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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.smartphone_rounded,
                            size: 13,
                            color: mutedTextColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _deviceSpecs,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: mutedTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Feedback Category Selector Chips
              Text(
                'FEEDBACK CATEGORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: IrisTokens.brand,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['name'];
                  return ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      cat['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : mutedTextColor,
                    ),
                    label: Text(
                      cat['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: IrisTokens.brand,
                    backgroundColor: (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? IrisTokens.brand
                            : (effectiveIsDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    onSelected: (val) {
                      if (val) {
                        IrisHaptics.selectionClick();
                        setState(() => _selectedCategory = cat['name'] as String);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // 5-Star Rating Selector
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  children: [
                    Text(
                      'RATE YOUR EXPERIENCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: IrisTokens.brand,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
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

              // Note / Suggestion Text Box
              Text(
                'YOUR THOUGHTS / SUGGESTIONS',
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
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share feature suggestions, bug reports, or feedback directly with the IRIS administrative team...',
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

              // Glowing Submit Transceiver Button
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
                              'TRANSMITTING TELEMETRY...',
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
