import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';

/// In-App User Feedback & Rating Screen for IRIS Mobile Client.
/// Auto-captures student/faculty credentials, user role (Student vs Faculty),
/// roll number, batch, exact device model & Android version,
/// submitting telemetry directly to Firebase Firestore ('feedback' collection).
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _batchController = TextEditingController();
  final _deviceController = TextEditingController();
  final _commentController = TextEditingController();

  String _userRole = 'Student'; // 'Student' or 'Faculty'
  String _selectedCategory = 'General Feedback';
  int _selectedRating = 5;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General Feedback',
    'Feature Request',
    'Bug Report',
    'UI/UX Polish',
    'Timetable Data Correction',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? prefs.getString('student_name') ?? '';
    final userBatch = prefs.getString('user_batch') ?? prefs.getString('student_batch') ?? '';
    final rollNo = prefs.getString('roll_number') ?? prefs.getString('student_id') ?? '';
    final savedRole = (prefs.getString('user_role') ?? prefs.getString('role') ?? '').toLowerCase();

    String detectedRole = 'Student';
    if (savedRole.contains('faculty') || savedRole.contains('teacher') || savedRole.contains('instructor') || savedRole.contains('prof')) {
      detectedRole = 'Faculty';
    }

    String deviceSpecs = 'Android Device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer;
      final model = androidInfo.model;
      final release = androidInfo.version.release;
      final sdk = androidInfo.version.sdkInt;
      deviceSpecs = '$manufacturer $model • Android $release (SDK $sdk)';
    } catch (_) {
      deviceSpecs = 'Android 15 Device';
    }

    if (mounted) {
      setState(() {
        _userRole = detectedRole;
        if (userName.isNotEmpty) _nameController.text = userName;
        if (userBatch.isNotEmpty) _batchController.text = userBatch;
        if (rollNo.isNotEmpty) _rollNumberController.text = rollNo;
        _deviceController.text = deviceSpecs;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNumberController.dispose();
    _batchController.dispose();
    _deviceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submitFeedback() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    IrisHaptics.actionHeavy();
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'name': _nameController.text.trim(),
        'user_role': _userRole,
        'roll_number': _rollNumberController.text.trim(),
        'batch': _batchController.text.trim(),
        'device': _deviceController.text.trim(),
        'category': _selectedCategory,
        'rating': _selectedRating,
        'comment': _commentController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'platform': 'Android Mobile Client',
      });

      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: Text(
            '$_userRole feedback submitted successfully! Thank you.',
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: IrisTokens.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.rate_review_rounded, color: IrisTokens.brand, size: 24),
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
                              color: effectiveIsDark ? Colors.white : Colors.black,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'share thoughts & feature requests with IRIS team',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Selector Segmented Switch
                      _buildLabel('I AM SUBMITTING AS'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                IrisHaptics.selectionClick();
                                setState(() => _userRole = 'Student');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _userRole == 'Student'
                                      ? IrisTokens.brand.withValues(alpha: 0.2)
                                      : (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _userRole == 'Student'
                                        ? IrisTokens.brand
                                        : (effectiveIsDark ? Colors.white12 : Colors.black12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school_rounded,
                                      size: 18,
                                      color: _userRole == 'Student' ? IrisTokens.brand : (effectiveIsDark ? Colors.white60 : Colors.black54),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Student',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: _userRole == 'Student' ? (effectiveIsDark ? Colors.white : Colors.black) : (effectiveIsDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                IrisHaptics.selectionClick();
                                setState(() => _userRole = 'Faculty');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _userRole == 'Faculty'
                                      ? Colors.purple.withValues(alpha: 0.2)
                                      : (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _userRole == 'Faculty'
                                        ? Colors.purpleAccent
                                        : (effectiveIsDark ? Colors.white12 : Colors.black12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_pin_rounded,
                                      size: 18,
                                      color: _userRole == 'Faculty' ? Colors.purpleAccent : (effectiveIsDark ? Colors.white60 : Colors.black54),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Faculty / Teacher',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: _userRole == 'Faculty' ? (effectiveIsDark ? Colors.white : Colors.black) : (effectiveIsDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Name Input
                      _buildLabel(_userRole == 'Faculty' ? 'FACULTY NAME' : 'STUDENT NAME'),
                      const SizedBox(height: 6),
                      _buildTextField(_nameController, hint: _userRole == 'Faculty' ? 'e.g. Dr. Usama Ejaz' : 'Enter your full name', validatorMsg: 'Please enter name', isDark: effectiveIsDark),
                      const SizedBox(height: 16),

                      // Roll Number & Batch Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(_userRole == 'Faculty' ? 'EMP ID / CODE' : 'ROLL / REG NO'),
                                const SizedBox(height: 6),
                                _buildTextField(_rollNumberController, hint: _userRole == 'Faculty' ? 'EMP-001' : 'SP26-BCS-001', validatorMsg: 'Enter ID', isDark: effectiveIsDark),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(_userRole == 'Faculty' ? 'DEPARTMENT' : 'BATCH / CLASS'),
                                const SizedBox(height: 6),
                                _buildTextField(_batchController, hint: _userRole == 'Faculty' ? 'Computer Science' : 'SP26-BCS-1-A', validatorMsg: 'Enter details', isDark: effectiveIsDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Device Details
                      _buildLabel('DEVICE & HARDWARE TELEMETRY'),
                      const SizedBox(height: 6),
                      _buildTextField(_deviceController, hint: 'Device details', validatorMsg: 'Enter device info', isDark: effectiveIsDark),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      _buildLabel('FEEDBACK CATEGORY'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: effectiveIsDark ? const Color(0xFF0F172A) : Colors.white,
                        style: TextStyle(color: effectiveIsDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(effectiveIsDark),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Star Rating
                      _buildLabel('SATISFACTION RATING'),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) {
                          final starNum = index + 1;
                          return IconButton(
                            icon: Icon(
                              starNum <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () {
                              IrisHaptics.selectionClick();
                              setState(() => _selectedRating = starNum);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Comment Input
                      _buildLabel('DETAILED COMMENTS'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 4,
                        style: TextStyle(color: effectiveIsDark ? Colors.white : Colors.black),
                        decoration: _inputDecoration(effectiveIsDark, hint: 'Share your experience or report an issue...'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter comments' : null,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitFeedback,
                          icon: _isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            _isSubmitting ? 'SUBMITTING...' : 'SUBMIT $_userRole.toUpperCase() FEEDBACK',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _userRole == 'Faculty' ? Colors.purple : IrisTokens.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: IrisTokens.brand,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {required String hint, required String validatorMsg, required bool isDark}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: _inputDecoration(isDark, hint: hint),
      validator: (v) => v == null || v.trim().isEmpty ? validatorMsg : null,
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
      filled: true,
      fillColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: IrisTokens.brand.withValues(alpha: 0.2)),
      ),
    );
  }
}
