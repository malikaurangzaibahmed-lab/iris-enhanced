import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../core/theme_signals.dart';

class NeuralAura extends StatefulWidget {
  final bool background;
  final String tone;

  const NeuralAura({super.key, required this.background, this.tone = 'default'});

  @override
  State<NeuralAura> createState() => _NeuralAuraState();
}

class _NeuralAuraState extends State<NeuralAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
      value: 0.5,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _lerpColorLists(List<Color> a, List<Color> b, double t) {
    final count = math.min(a.length, b.length);
    if (count == 0) return const [];
    return List<Color>.generate(
      count,
      (index) => Color.lerp(a[index], b[index], t) ?? a[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ThemeSignals.useMinimalTheme.value) {
      return const SizedBox.shrink();
    }
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    List<Color> toneStopsDark() {
      switch (widget.tone) {
        case 'core':
          return [
            const Color(0xFF020617),
            const Color(0xFF0F2040),
            const Color(0xFF020617),
          ];
        case 'cs':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.blue.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'health':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.teal.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.warningDark.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.purple.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        default:
          return [
            IrisTokens.surfaceDark,
            IrisTokens.surfaceDark,
            IrisTokens.surfaceDarkElevated,
            IrisTokens.surfaceDarkElevated,
          ];
      }
    }

    List<Color> toneStopsDarkAlt() {
      switch (widget.tone) {
        case 'core':
          return [
            const Color(0xFF0A1430),
            const Color(0xFF020617),
            const Color(0xFF0F2040),
          ];
        case 'cs':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.brand.withValues(alpha: 0.14),
            IrisTokens.surfaceDark,
          ];
        case 'health':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.success.withValues(alpha: 0.14),
            IrisTokens.surfaceDark,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.warning.withValues(alpha: 0.13),
            IrisTokens.surfaceDark,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.blue.withValues(alpha: 0.13),
            IrisTokens.surfaceDark,
          ];
        default:
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.brand.withValues(alpha: 0.10),
            IrisTokens.surfaceDark,
            IrisTokens.surfaceDark,
          ];
      }
    }

    List<Color> toneStopsLight() {
      switch (widget.tone) {
        case 'core':
          return [
            const Color(0xFFF1F5F9),
            const Color(0xFFEADDFF),
            const Color(0xFFF8FAFC),
            const Color(0xFFD3E4FF),
            const Color(0xFFF1F5F9),
            const Color(0xFFF8FAFC),
          ];
        case 'cs':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.blueLight.withValues(alpha: 0.16),
            IrisTokens.surfaceLightElevated,
            IrisTokens.brandLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'health':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.teal.withValues(alpha: 0.16),
            IrisTokens.surfaceLightElevated,
            IrisTokens.success.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.warning.withValues(alpha: 0.14),
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.purpleLight.withValues(alpha: 0.16),
            IrisTokens.surfaceLightElevated,
            IrisTokens.blueLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'learning':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.pinkLight.withValues(alpha: 0.14),
            IrisTokens.surfaceLightElevated,
            IrisTokens.teal.withValues(alpha: 0.08),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        default:
          return [
            IrisTokens.surfaceLight,
            IrisTokens.brandLight.withValues(alpha: 0.15),
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
      }
    }

    List<Color> toneStopsLightAlt() {
      switch (widget.tone) {
        case 'core':
          return [
            const Color(0xFFF8FAFC),
            const Color(0xFFD3E4FF),
            const Color(0xFFF1F5F9),
            const Color(0xFFEADDFF),
            const Color(0xFFF8FAFC),
            const Color(0xFFF1F5F9),
          ];
        case 'cs':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.brandLight.withValues(alpha: 0.14),
            IrisTokens.surfaceLight,
            IrisTokens.blueLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'health':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.success.withValues(alpha: 0.14),
            IrisTokens.surfaceLight,
            IrisTokens.teal.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.12),
            IrisTokens.surfaceLight,
            IrisTokens.warning.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.blueLight.withValues(alpha: 0.13),
            IrisTokens.surfaceLight,
            IrisTokens.purpleLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'learning':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.teal.withValues(alpha: 0.12),
            IrisTokens.surfaceLight,
            IrisTokens.pinkLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        default:
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.12),
            IrisTokens.surfaceLight,
            IrisTokens.brandLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
      }
    }

    List<Color> toneMeshLight() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.brandLight.withValues(alpha: 0.11),
            Colors.transparent,
            IrisTokens.teal.withValues(alpha: 0.06),
          ];
        case 'cs':
          return [
            IrisTokens.blueLight.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.brandLight.withValues(alpha: 0.08),
          ];
        case 'health':
          return [
            IrisTokens.teal.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.success.withValues(alpha: 0.07),
          ];
        case 'engineering':
          return [
            IrisTokens.warning.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.pinkLight.withValues(alpha: 0.05),
          ];
        case 'analytics':
          return [
            IrisTokens.purpleLight.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.blueLight.withValues(alpha: 0.06),
          ];
        case 'learning':
          return [
            IrisTokens.pinkLight.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.teal.withValues(alpha: 0.05),
          ];
        default:
          return [
            IrisTokens.brandLight.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.pinkLight.withValues(alpha: 0.06),
          ];
      }
    }

    List<Color> toneMeshLightAlt() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.teal.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.brandLight.withValues(alpha: 0.07),
          ];
        case 'cs':
          return [
            IrisTokens.brandLight.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.blueLight.withValues(alpha: 0.06),
          ];
        case 'health':
          return [
            IrisTokens.success.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.teal.withValues(alpha: 0.06),
          ];
        case 'engineering':
          return [
            IrisTokens.pinkLight.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.warning.withValues(alpha: 0.06),
          ];
        case 'analytics':
          return [
            IrisTokens.blueLight.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.purpleLight.withValues(alpha: 0.06),
          ];
        case 'learning':
          return [
            IrisTokens.teal.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.pinkLight.withValues(alpha: 0.05),
          ];
        default:
          return [
            IrisTokens.pinkLight.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.brandLight.withValues(alpha: 0.05),
          ];
      }
    }

    Color darkPrimaryAccent() {
      switch (widget.tone) {
        case 'core':
          return IrisTokens.brand.withValues(alpha: 0.12);
        case 'cs':
          return IrisTokens.blue.withValues(alpha: 0.10);
        case 'health':
          return IrisTokens.teal.withValues(alpha: 0.10);
        case 'engineering':
          return IrisTokens.warning.withValues(alpha: 0.10);
        case 'analytics':
          return IrisTokens.purple.withValues(alpha: 0.10);
        default:
          return IrisTokens.brand.withValues(alpha: 0.08);
      }
    }

    Color darkSecondaryAccent() {
      switch (widget.tone) {
        case 'core':
          return IrisTokens.teal.withValues(alpha: 0.07);
        case 'cs':
          return IrisTokens.brand.withValues(alpha: 0.08);
        case 'health':
          return IrisTokens.success.withValues(alpha: 0.08);
        case 'engineering':
          return IrisTokens.pink.withValues(alpha: 0.07);
        case 'analytics':
          return IrisTokens.blue.withValues(alpha: 0.07);
        default:
          return IrisTokens.purple.withValues(alpha: 0.06);
      }
    }

    final reduceMotion =
        IrisMotion.reduceMotion || MediaQuery.of(context).disableAnimations;

    return TickerMode(
      enabled: !reduceMotion,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = reduceMotion ? 0.42 : _controller.value;
          final phase = t * 2 * math.pi;
          final wave = 0.5 + (0.5 * math.sin(phase));
          final waveSlow = 0.5 + (0.5 * math.sin((phase * 0.72) + 0.9));
          final driftX = 0.30 * math.sin(phase + 1.0);
          final driftY = 0.22 * math.cos((phase * 0.86) + 0.6);
          final shimmer = 0.5 + (0.5 * math.sin((phase * 2.3) + 2.2));
          final pulse = 0.5 + (0.5 * math.sin((phase * 1.45) + 0.4));

          final baseColors = widget.background
              ? _lerpColorLists(toneStopsDark(), toneStopsDarkAlt(), wave)
              : _lerpColorLists(toneStopsLight(), toneStopsLightAlt(), wave);

          final meshColors = widget.background
              ? _lerpColorLists(
                  [darkPrimaryAccent(), Colors.transparent, darkSecondaryAccent()],
                  [darkSecondaryAccent(), Colors.transparent, darkPrimaryAccent()],
                  wave,
                )
              : _lerpColorLists(toneMeshLight(), toneMeshLightAlt(), wave);

          return RepaintBoundary(
            child: Stack(
              children: [
                // Base gradient — deeper, richer
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + driftX, -1.0 + driftY),
                      end: Alignment(1.0 - driftX, 1.0 - driftY),
                      colors: baseColors,
                      stops: widget.background
                          ? const [0.0, 0.3, 0.7, 1.0]
                          : const [0.0, 0.15, 0.35, 0.55, 0.78, 1.0],
                    ),
                  ),
                ),

                // Mesh overlay for premium depth
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(1.0 - driftY, -1.0 + driftX),
                          end: Alignment(-1.0 + driftY, 1.0 - driftX),
                          colors: meshColors,
                        ),
                      ),
                    ),
                  ),
                ),

                // Sweeping highlight layer for livelier movement
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: widget.background
                          ? (0.06 + (shimmer * 0.05))
                          : (0.05 + (shimmer * 0.06)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.2 + (waveSlow * 1.6), -1.0),
                            end: Alignment(-0.2 + (waveSlow * 1.6), 1.0),
                            colors: [
                              Colors.transparent,
                              (widget.background ? Colors.white : IrisTokens.brand)
                                  .withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Counter sweep to avoid static directional feel
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: widget.background
                          ? (0.04 + (pulse * 0.05))
                          : (0.03 + (pulse * 0.05)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(1.1 - (waveSlow * 1.5), -1.0),
                            end: Alignment(0.1 - (waveSlow * 1.5), 1.0),
                            colors: [
                              Colors.transparent,
                              (widget.background
                                      ? IrisTokens.blue
                                      : IrisTokens.purple)
                                  .withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Moving pulse core for energetic depth
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(
                              -0.5 + (wave * 1.0), -0.2 + ((1 - wave) * 0.8)),
                          radius: 0.9 + (pulse * 0.2),
                          colors: [
                            (widget.background ? IrisTokens.teal : IrisTokens.brand)
                                .withValues(alpha: 0.10 + (pulse * 0.08)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

            if (widget.background)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.9 - driftX, -0.9 + (driftY * 0.6)),
                        radius: 1.0,
                        colors: [
                          darkPrimaryAccent(),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (widget.background)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.9 + (driftY * 0.6), 0.9 - driftX),
                        radius: 1.0,
                        colors: [
                          darkSecondaryAccent(),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (!widget.background)
              Positioned(
                top: -160,
                left: -120,
                child: AuraBlob(
                  colors: [
                    IrisTokens.brand.withValues(alpha: 0.14),
                    IrisTokens.brandLight.withValues(alpha: 0.08),
                    IrisTokens.brandLight.withValues(alpha: 0.03),
                  ],
                  size: 460,
                ),
              ),

            if (!widget.background)
              Positioned(
                top: -60,
                right: -100,
                child: AuraBlob(
                  colors: [
                    IrisTokens.pink.withValues(alpha: 0.10),
                    IrisTokens.pink.withValues(alpha: 0.05),
                    IrisTokens.pinkLight.withValues(alpha: 0.02),
                  ],
                  size: 320,
                ),
              ),

            // Bottom-right — deep purple
            if (!widget.background)
              Positioned(
                bottom: -140,
                right: -120,
                child: AuraBlob(
                  colors: [
                    IrisTokens.purple.withValues(alpha: 0.12),
                    IrisTokens.purpleLight.withValues(alpha: 0.06),
                    IrisTokens.purpleLight.withValues(alpha: 0.03),
                  ],
                  size: 500,
                ),
              ),

            if (widget.background)
              Positioned(
                top: -120,
                left: -120,
                child: AuraBlob(
                  colors: [
                    IrisTokens.brand.withValues(alpha: 0.08),
                    IrisTokens.brand.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  size: 440,
                ),
              ),

            if (widget.background)
              Positioned(
                top: 20,
                right: -110,
                child: AuraBlob(
                  colors: [
                    IrisTokens.purple.withValues(alpha: 0.08),
                    IrisTokens.purpleLight.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  size: 360,
                ),
              ),

            if (widget.background)
              Positioned(
                bottom: -130,
                left: -90,
                child: AuraBlob(
                  colors: [
                    IrisTokens.teal.withValues(alpha: 0.07),
                    IrisTokens.success.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  size: 380,
                ),
              ),

            if (widget.background)
              Positioned(
                bottom: -150,
                right: -140,
                child: AuraBlob(
                  colors: [
                    IrisTokens.warning.withValues(alpha: 0.06),
                    IrisTokens.warningDark.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  size: 420,
                ),
              ),

            if (!widget.background)
              Positioned(
                top: h * 0.32,
                right: -90,
                child: AuraBlob(
                  colors: [
                    IrisTokens.warning.withValues(alpha: 0.07),
                    IrisTokens.warning.withValues(alpha: 0.04),
                    IrisTokens.warningDark.withValues(alpha: 0.02),
                  ],
                  size: 300,
                ),
              ),

            if (!widget.background)
              Positioned(
                bottom: h * 0.12,
                left: -80,
                child: AuraBlob(
                  colors: [
                    IrisTokens.teal.withValues(alpha: 0.08),
                    IrisTokens.success.withValues(alpha: 0.04),
                    IrisTokens.successDark.withValues(alpha: 0.02),
                  ],
                  size: 320,
                ),
              ),

            if (!widget.background)
              Positioned(
                top: h * 0.18,
                left: w * 0.25,
                child: AuraBlob(
                  colors: [
                    IrisTokens.blue.withValues(alpha: 0.05),
                    IrisTokens.blueLight.withValues(alpha: 0.03),
                    IrisTokens.brandLight.withValues(alpha: 0.01),
                  ],
                  size: 240,
                ),
              ),

            if (!widget.background)
              Positioned(
                top: h * 0.6,
                left: w * 0.4,
                child: AuraBlob(
                  colors: [
                    IrisTokens.purple.withValues(alpha: 0.06),
                    IrisTokens.purple.withValues(alpha: 0.03),
                    IrisTokens.purpleLight.withValues(alpha: 0.01),
                  ],
                  size: 260,
                ),
              ),

            // Subtle grain/noise overlay for depth
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, -1.0 + (driftX * 0.7)),
                      end: Alignment(0, 1.0 - (driftY * 0.7)),
                      colors: [
                        Colors.transparent,
                        (widget.background ? Colors.black : Colors.white)
                            .withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        );
      },
      ),
    );
  }
}

class AuraBlob extends StatefulWidget {
  final List<Color> colors;
  final double size;

  const AuraBlob({super.key, required this.colors, required this.size});

  @override
  State<AuraBlob> createState() => _AuraBlobState();
}

class _AuraBlobState extends State<AuraBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final durationMs = (3200 + (widget.size * 4)).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
      value: 0.5,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = (widget.size % 97) / 97;
    final travel = (widget.size / 280.0).clamp(0.95, 2.2);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final p = (t + phase) * 2 * math.pi;
        final floatY =
            (math.sin(p) * 10.5 + math.sin((p * 0.68) + 0.8) * 5.0) * travel;
        final floatX =
            (math.cos((p * 0.94) + 0.5) * 6.2 + math.sin((p * 0.42) + 1.1) * 2.6) *
                travel;
        final scale = 0.975 + (math.sin((p * 0.82) + 0.3) * 0.022);

        return Transform.translate(
          offset: Offset(floatX, floatY),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: widget.colors,
                  stops: widget.colors.length == 3
                      ? const [0.0, 0.6, 1.0]
                      : const [0.0, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.colors.first).withValues(alpha: 0.16),
                    blurRadius: widget.size * 0.15,
                    spreadRadius: widget.size * -0.08,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
