import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../widgets/smooth_scroll.dart';
import '../services/ui_feedback.dart';
import '../core/vital_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = IrisTokens.purple;
    const purpleLight = IrisTokens.purpleLight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        elevation: 0,
        leading: AppBackButton(isDark: isDark),
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [purple, purpleLight],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'nexsync database & local sync protocols',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
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
                        _buildSectionTitle(context, '1. DATA CONTROLLER', isDark),
                        _buildSectionBody(
                          context,
                          'Nexsync (IRIS) operates as a localized intelligence companion. All data sync mechanisms are run locally on your device. We do not operate remote centralized database clusters for profiling, meaning your data remains solely in your custody.',
                          isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '2. INFORMATION PROCESSING', isDark),
                        _buildSectionBody(
                          context,
                          'We collect and store local preferences using secure key-value stores (SharedPreferences):\n'
                          '• Identity telemetry: Display Name, User Role (Student/Faculty), and Academic Batch Key.\n'
                          '• Hyper-Sync timetable metadata: Class schedule details, course timings, located teacher identifiers, and room allocations.\n'
                          '• Sensor configurations: Audio switches and haptic profile parameters.',
                          isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '3. TIMETABLE SYNCHRONIZATION', isDark),
                        _buildSectionBody(
                          context,
                          'The timetable scraper operates client-side on your device. Timetable data is downloaded directly from official university systems to your local memory cache. No scheduling information or authentication tokens are ever transmitted to third-party endpoints or stored outside your device.',
                          isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '4. SECURITY STANDARDS', isDark),
                        _buildSectionBody(
                          context,
                          'We apply strict device-level formatting bounds to ensure no SQL injections or memory buffer overflow leaks can trigger code execution vulnerabilities. Local cache encryption layers protect persistent session variables from unauthorized access.',
                          isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '5. CONTACT & AUDIT', isDark),
                        _buildSectionBody(
                          context,
                          'For questions regarding security audits or local storage keys, contact the development group:\nmalikaurangzaibahmed@gmail.com',
                          isDark,
                        ),
                      ],
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

  Widget _buildSectionTitle(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: IrisTokens.brand,
        ),
      ),
    );
  }

  Widget _buildSectionBody(BuildContext context, String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.75),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  final VoidCallback? onBackPressed;
  final bool? isDark;

  const TermsOfServiceScreen({
    super.key,
    this.onBackPressed,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        elevation: 0,
        leading: AppBackButton(
          isDark: effectiveIsDark,
          onPressed: onBackPressed,
        ),
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
              physics: const BouncingScrollPhysics(),
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
                        child: const Icon(Icons.gavel_rounded, color: IrisTokens.brand, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: effectiveIsDark ? Colors.white : Colors.black,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'legal framework & user guidelines',
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
                        _buildSectionTitle(context, '1. AGREEMENT TO TERMS', effectiveIsDark),
                        _buildSectionBody(
                          context,
                          'By initializing and running IRIS client services, you agree to comply with the rules outlined herein. This application is an unofficial companion and has no direct corporate affiliation with COMSATS University.',
                          effectiveIsDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '2. SCRAPING ETHICS', effectiveIsDark),
                        _buildSectionBody(
                          context,
                          'The local scraper is throttled and designed to prevent request floods on university portals. You agree not to bypass the local caching systems or execute custom automated queries that could generate excessive traffic loads.',
                          effectiveIsDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '3. DISCLAIMER OF WARRANTIES', effectiveIsDark),
                        _buildSectionBody(
                          context,
                          'IRIS is provided "as-is". While our parsing algorithms are highly accurate, timetables are subject to sudden shifts, cancellations, or administrative changes. The authors are not liable for attendance deficits, scheduling conflicts, or class/exam missed slots due to data desynchronization.',
                          effectiveIsDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '4. SYSTEM RESTRAINTS', effectiveIsDark),
                        _buildSectionBody(
                          context,
                          'You may not modify the compiled APK, perform reverse engineering of local haptic curves, or use the timetable database extraction tools for commercial purposes without explicit permission.',
                          effectiveIsDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, '5. PROTOCOL REVISIONS', effectiveIsDark),
                        _buildSectionBody(
                          context,
                          'We reserve the right to revise these terms to align with portal structure updates or security requirements. Continued usage of IRIS constitutes acceptance of updated disclaimers.',
                          effectiveIsDark,
                        ),
                      ],
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

  Widget _buildSectionTitle(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: IrisTokens.brand,
        ),
      ),
    );
  }

  Widget _buildSectionBody(BuildContext context, String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.75),
      ),
    );
  }
}
