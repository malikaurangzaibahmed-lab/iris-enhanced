import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../core/animations.dart';
import '../screens/iris_hub_screen.dart';

/// A powerful 3D gesture wrapper that pushes your main application into the background,
/// revealing a sleek, frosted Command Center underneath.
class CommandCenterOverlay extends StatefulWidget {
  final Widget child; // The main UI to be wrapped

  const CommandCenterOverlay({super.key, required this.child});

  @override
  State<CommandCenterOverlay> createState() => CommandCenterOverlayState();
  
  /// Expose the state so child widgets can trigger the menu via buttons (e.g., hamburger icon)
  /// `CommandCenterOverlay.of(context)?.toggle();`
  static CommandCenterOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<CommandCenterOverlayState>();
  }
}

class CommandCenterOverlayState extends State<CommandCenterOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _radiusAnim;

  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    // Use an aggressively bouncy spring curve for premium tactile feel
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    final curve = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    
    // The 3D Push-back effect (Shrink the main app to 85% scale)
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(curve);
    
    // The Slide effect (Push the app right to reveal the hidden layer)
    _slideAnim = Tween<double>(begin: 0.0, end: 0.65).animate(curve);
    
    // The Edge rounding (Main app gets soft corners when pushed back)
    _radiusAnim = Tween<double>(begin: 0.0, end: 32.0).animate(curve);
  }

  void toggle() {
    if (_isOpen) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
    _isOpen = !_isOpen;
  }

  Future<void> _logout() async {
    // Zero-Cost Firebase Auth destruction
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Just toggle the menu back. The UI will react to the null user state.
      toggle();
      IrisHaptics.refreshSuccess();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: IrisTokens.surfaceDark, // Deep black for iOS 18 depth
      body: Stack(
        children: [
          // 1. The Underside Layer: The Command Center Menu
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Opacity(
                  opacity: _animController.value,
                  // Parallax effect: The menu slides slightly in from the left 
                  child: Transform.translate(
                    offset: Offset(-sw * 0.2 * (1 - _animController.value), 0),
                    child: child,
                  ),
                );
              },
              child: _buildMenuContent(context),
            ),
          ),
          
          // 2. The Top Layer: The deeply wrapped Main App
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform(
                // Setup the 3D Matrix
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Adds depth/perspective
                  ..scale(_scaleAnim.value)
                  ..translate(sw * _slideAnim.value, 0.0),
                alignment: Alignment.centerLeft,
                
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radiusAnim.value),
                  child: GestureDetector(
                    // Interactive Swipe Gestures
                    onTap: _isOpen ? toggle : null, // If open, tapping the squished app closes it
                    onHorizontalDragUpdate: (details) {
                       double delta = details.primaryDelta! / sw;
                       _animController.value += delta;
                    },
                    onHorizontalDragEnd: (details) {
                      if (_animController.value > 0.4 || details.primaryVelocity! > 300) {
                        _animController.forward();
                        _isOpen = true;
                      } else {
                        _animController.reverse();
                        _isOpen = false;
                      }
                    },
                    // AbsorbPointer freezing the app when pushed back so users don't accidentally click things
                    child: AbsorbPointer(
                      absorbing: _isOpen,
                      child: Container(
                        // Gives the app a heavy shadow rim when floating above the menu
                        decoration: BoxDecoration(
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: -10)
                          ]
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuContent(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final baseColor = Colors.white;

    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      padding: const EdgeInsets.only(top: 100, left: 32, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Floating Profile Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: IrisTokens.brand.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2
                )
              ]
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: baseColor.withOpacity(0.1),
              child: const Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            user?.email?.split('@').first.toUpperCase() ?? "GUEST",
            style: TextStyle(color: baseColor, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          Text(
            user?.email ?? "Offline Instance",
            style: TextStyle(color: baseColor.withOpacity(0.6), fontSize: 14),
          ),
          
          const SizedBox(height: 50),
          
          _buildMenuItem(Icons.dashboard_rounded, "Dashboard", () => toggle()),
          _buildMenuItem(Icons.person_rounded, "IRIS Hub", () {
            toggle();
            pushIconLaunchRoute(context, page: const IrisHubScreen());
          }),
          
          // Admin Panel removed in favor of centralized Web Admin Portal (https://iris-138ef.web.app)

          const Spacer(),
          
          Divider(color: baseColor.withOpacity(0.1)),
          // Secure Logout trigger
          _buildMenuItem(Icons.power_settings_new_rounded, "Log Out", _logout, color: IrisTokens.error),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color ?? Colors.white.withOpacity(0.8), size: 28),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color ?? Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
