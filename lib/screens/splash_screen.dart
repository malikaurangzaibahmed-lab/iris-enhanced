import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'portal_screen.dart'; // Adjust if your main dashboard is named differently
import '../core/tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600), // Cinematic duration
    );

    // 2. Define Liquid Glass Orb Scale Sequence (Breath + Pop)
    _scaleAnimation = TweenSequence<double>([
      // Breathe In (Slight expand)
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.6, end: 1.1)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 30),
      // Recoil (Slight compress before pop)
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.1, end: 0.95)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 20),
      // The "Pop" / Awakening Expand
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.95, end: 4.5)
              .chain(CurveTween(curve: Curves.easeOutExpo)),
          weight: 50),
    ]).animate(_controller);

    // 3. Define Opacity (Fade In, Hold, Fade out at end as it swallows the screen)
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
    ]).animate(_controller);

    // 4. Map Progressive Haptics precisely to timeline milestones
    _controller.addListener(() {
      final val = _controller.value;
      
      // Milestone 1: Start (Subtle click)
      if ((val - 0.1).abs() < 0.005) HapticFeedback.selectionClick();
      // Milestone 2: Breathe Peak (Light pulse)
      if ((val - 0.3).abs() < 0.005) HapticFeedback.lightImpact();
      // Milestone 3: Recoil Floor (Medium impact as it winds up)
      if ((val - 0.5).abs() < 0.005) HapticFeedback.mediumImpact();
      // Milestone 4: Exponential 'Pop' (Heavy tactical vibration)
      if ((val - 0.65).abs() < 0.005) HapticFeedback.heavyImpact();
    });

    // Begin Awakening sequence
    _controller.forward();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adjust colors depending on device theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Assuming IrisTokens.surfaceDark / Light exist in your main.dart
    final bgColor = isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Hero(
            tag: 'liquid_glass_orb',
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    IrisTokens.brandLight,
                    IrisTokens.brand,
                  ],
                  stops: [0.3, 1.0],
                ),
                boxShadow: [
                  // Inner Core Glow
                  BoxShadow(
                    color: IrisTokens.brandLight.withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                  // Outer Dispersion
                  BoxShadow(
                    color: IrisTokens.brand.withOpacity(0.3),
                    blurRadius: 80,
                    spreadRadius: 20,
                  )
                ],
              ),
              // We can place the IRIS transparent logo right in the middle
              // child: Center(child: Image.asset('assets/iris_logo.png', width: 60)),
            ),
          ),
        ),
      ),
    );
  }
}
