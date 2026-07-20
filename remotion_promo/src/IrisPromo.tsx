import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Img,
  Sequence,
  staticFile,
} from "remotion";
import React from "react";

export const IrisPromo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Intro calculations
  const introLogoScale = spring({
    frame,
    fps,
    config: { damping: 12 },
  });

  const introTextOpacity = interpolate(frame, [15, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Scene transitions
  const scene1Opacity = interpolate(frame, [50, 60], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const scene2Opacity = interpolate(frame, [60, 65, 115, 120], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const scene3Opacity = interpolate(frame, [120, 125, 175, 180], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const scene4Opacity = interpolate(frame, [180, 185], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Scene 2: Dashboard Mockup animation
  const dbProgress = spring({
    frame: frame - 60,
    fps,
    config: { damping: 15 },
  });
  const dbScale = interpolate(dbProgress, [0, 1], [0.8, 1]);
  const dbRotateY = interpolate(dbProgress, [0, 1], [25, -5]);
  const dbRotateX = interpolate(dbProgress, [0, 1], [15, 8]);

  // Scene 3: Bento Grid items animation
  const gridItem1 = spring({ frame: frame - 122, fps, config: { damping: 12 } });
  const gridItem2 = spring({ frame: frame - 128, fps, config: { damping: 12 } });
  const gridItem3 = spring({ frame: frame - 134, fps, config: { damping: 12 } });

  // Outro calculations
  const outroScale = spring({ frame: frame - 180, fps, config: { damping: 10 } });

  // Background gradient shift
  const bgShift = interpolate(frame, [0, 240], [0, 100]);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0d0e12",
        fontFamily: "system-ui, -apple-system, sans-serif",
        color: "white",
        overflow: "hidden",
      }}
    >
      {/* Background Radial Glow */}
      <div
        style={{
          position: "absolute",
          top: "-50%",
          left: "-50%",
          width: "200%",
          height: "200%",
          background: `radial-gradient(circle, rgba(119,77,226,0.18) 0%, rgba(20,22,28,0) 60%)`,
          transform: `translate(${Math.sin(bgShift / 20) * 100}px, ${Math.cos(bgShift / 20) * 100}px)`,
        }}
      />

      {/* SCENE 1: Intro (0 - 60 frames) */}
      <Sequence from={0} durationInFrames={60}>
        <AbsoluteFill
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            opacity: scene1Opacity,
          }}
        >
          <div
            style={{
              transform: `scale(${introLogoScale})`,
              filter: "drop-shadow(0 0 40px rgba(119,77,226,0.6))",
              width: 180,
              height: 180,
              borderRadius: "50%",
              overflow: "hidden",
              marginBottom: 30,
            }}
          >
            <Img src={staticFile("logo.png")} style={{ width: "100%", height: "100%" }} />
          </div>
          <h1
            style={{
              fontSize: 80,
              fontWeight: 900,
              letterSpacing: "-2px",
              background: "linear-gradient(135deg, #a78bfa 0%, #14b8a6 100%)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
              opacity: introTextOpacity,
              margin: 0,
            }}
          >
            IRIS
          </h1>
          <p
            style={{
              fontSize: 28,
              fontWeight: 500,
              color: "#94a3b8",
              marginTop: 10,
              opacity: introTextOpacity,
              letterSpacing: "1px",
            }}
          >
            The Future of Academics
          </p>
        </AbsoluteFill>
      </Sequence>

      {/* SCENE 2: The Dashboard Mockup (60 - 120 frames) */}
      <Sequence from={60} durationInFrames={60}>
        <AbsoluteFill
          style={{
            display: "flex",
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            padding: "0 100px",
            opacity: scene2Opacity,
          }}
        >
          {/* Floating Device Showcase */}
          <div
            style={{
              width: "55%",
              perspective: 1200,
              display: "flex",
              justifyContent: "center",
            }}
          >
            <div
              style={{
                width: "90%",
                borderRadius: 24,
                overflow: "hidden",
                border: "1px solid rgba(255,255,255,0.12)",
                boxShadow: "0 30px 60px rgba(0,0,0,0.5), 0 0 50px rgba(119,77,226,0.15)",
                transform: `scale(${dbScale}) rotateY(${dbRotateY}deg) rotateX(${dbRotateX}deg)`,
                transformStyle: "preserve-3d",
              }}
            >
              <Img src={staticFile("dashboard.png")} style={{ width: "100%" }} />
            </div>
          </div>

          {/* Value Propositions */}
          <div style={{ width: "38%", display: "flex", flexDirection: "column" }}>
            <h2
              style={{
                fontSize: 52,
                fontWeight: 900,
                letterSpacing: "-1.5px",
                margin: 0,
                background: "linear-gradient(135deg, #ffffff 0%, #a78bfa 100%)",
                WebkitBackgroundClip: "text",
                WebkitTextFillColor: "transparent",
              }}
            >
              Obsidian Glass
            </h2>
            <p
              style={{
                fontSize: 22,
                color: "#94a3b8",
                lineHeight: 1.5,
                marginTop: 15,
                fontWeight: 500,
              }}
            >
              An elegant design system engineered with premium micro-blur, responsive card layers, and real-time visual signals.
            </p>
          </div>
        </AbsoluteFill>
      </Sequence>

      {/* SCENE 3: Bento Grid Layout (120 - 180 frames) */}
      <Sequence from={120} durationInFrames={60}>
        <AbsoluteFill
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            padding: "0 100px",
            opacity: scene3Opacity,
          }}
        >
          <h2
            style={{
              fontSize: 48,
              fontWeight: 900,
              letterSpacing: "-1px",
              marginBottom: 40,
              background: "linear-gradient(135deg, #14b8a6 0%, #a78bfa 100%)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}
          >
            Engineered Features
          </h2>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(3, 1fr)",
              gap: 24,
              width: "100%",
              maxWidth: 1200,
            }}
          >
            {/* Grid 1 */}
            <div
              style={{
                background: "rgba(255,255,255,0.03)",
                border: "1px solid rgba(255,255,255,0.06)",
                borderRadius: 20,
                padding: 30,
                transform: `scale(${gridItem1})`,
                boxShadow: "0 20px 40px rgba(0,0,0,0.15)",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                textAlign: "center",
              }}
            >
              <div
                style={{
                  width: 60,
                  height: 60,
                  borderRadius: 16,
                  background: "rgba(167,139,250,0.15)",
                  color: "#a78bfa",
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                  fontSize: 28,
                  fontWeight: "bold",
                  marginBottom: 20,
                }}
              >
                ⚡
              </div>
              <h3 style={{ fontSize: 22, fontWeight: 700, margin: "0 0 10px 0" }}>Hyper-Sync</h3>
              <p style={{ fontSize: 15, color: "#94a3b8", lineHeight: 1.5, margin: 0 }}>
                Real-time synchronization engine keeps class schedules aligned instantly.
              </p>
            </div>

            {/* Grid 2 */}
            <div
              style={{
                background: "rgba(255,255,255,0.03)",
                border: "1px solid rgba(255,255,255,0.06)",
                borderRadius: 20,
                padding: 30,
                transform: `scale(${gridItem2})`,
                boxShadow: "0 20px 40px rgba(0,0,0,0.15)",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                textAlign: "center",
              }}
            >
              <div
                style={{
                  width: 60,
                  height: 60,
                  borderRadius: 16,
                  background: "rgba(20,184,166,0.15)",
                  color: "#14b8a6",
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                  fontSize: 28,
                  fontWeight: "bold",
                  marginBottom: 20,
                }}
              >
                🔍
              </div>
              <h3 style={{ fontSize: 22, fontWeight: 700, margin: "0 0 10px 0" }}>Browse Classes</h3>
              <p style={{ fontSize: 15, color: "#94a3b8", lineHeight: 1.5, margin: 0 }}>
                Filter classes by program, semester, and section via smooth glass menus.
              </p>
            </div>

            {/* Grid 3 */}
            <div
              style={{
                background: "rgba(255,255,255,0.03)",
                border: "1px solid rgba(255,255,255,0.06)",
                borderRadius: 20,
                padding: 30,
                transform: `scale(${gridItem3})`,
                boxShadow: "0 20px 40px rgba(0,0,0,0.15)",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                textAlign: "center",
              }}
            >
              <div
                style={{
                  width: 60,
                  height: 60,
                  borderRadius: 16,
                  background: "rgba(139,92,246,0.15)",
                  color: "#8b5cf6",
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                  fontSize: 28,
                  fontWeight: "bold",
                  marginBottom: 20,
                }}
              >
                🎛️
              </div>
              <h3 style={{ fontSize: 22, fontWeight: 700, margin: "0 0 10px 0" }}>Glass Toggles</h3>
              <p style={{ fontSize: 15, color: "#94a3b8", lineHeight: 1.5, margin: 0 }}>
                Adjust preferences with beautiful tactile sliding glass toggles.
              </p>
            </div>
          </div>
        </AbsoluteFill>
      </Sequence>

      {/* SCENE 4: Outro (180 - 240 frames) */}
      <Sequence from={180}>
        <AbsoluteFill
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            opacity: scene4Opacity,
          }}
        >
          <div
            style={{
              transform: `scale(${outroScale})`,
              filter: "drop-shadow(0 0 50px rgba(119,77,226,0.6))",
              width: 200,
              height: 200,
              borderRadius: "50%",
              overflow: "hidden",
              marginBottom: 30,
            }}
          >
            <Img src={staticFile("logo.png")} style={{ width: "100%", height: "100%" }} />
          </div>
          <h2
            style={{
              fontSize: 60,
              fontWeight: 900,
              letterSpacing: "-2px",
              margin: 0,
              background: "linear-gradient(135deg, #a78bfa 0%, #14b8a6 100%)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}
          >
            Elevate Your Experience
          </h2>
          <p
            style={{
              fontSize: 24,
              color: "#94a3b8",
              marginTop: 10,
              fontWeight: 500,
              letterSpacing: "0.5px",
            }}
          >
            Seamless Academics. Sleek Interfaces.
          </p>
        </AbsoluteFill>
      </Sequence>
    </AbsoluteFill>
  );
};
