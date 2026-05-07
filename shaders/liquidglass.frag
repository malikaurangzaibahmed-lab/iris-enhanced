#version 460
precision highp float;

#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

uniform vec2 uSize;
uniform float uRadius;
uniform float uRefractionHeight; 
uniform float uRefractionAmount; 
uniform float uDispersion;
uniform vec2 uWarpOffset;      // ELASTIC PHYSICS OFFSET
uniform vec2 uGlowPos;          // TOUCH GLOW POS
uniform float uGlowIntensity;   // TOUCH GLOW RADIUS/POWER
uniform vec3 uTintColor;        // CONFIGURABLE TINT (God-Mode vs Student)
uniform float uTintAlpha;       // TINT INTENSITY
uniform sampler2D uImage; 

const vec3 rgbToY = vec3(0.2126, 0.7152, 0.0722);

float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, 0.0));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

float circleMap(float x) {
    return 1.0 - sqrt(clamp(1.0 - x * x, 0.0, 1.0));
}

vec3 saturateColor(vec3 color, float amount) {
    float y = dot(color, rgbToY);
    return mix(vec3(y), color, amount);
}

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 halfSize = uSize * 0.5;
    
    // Apply Warp Translation to the Sampling coordinate system
    // This creates the "Sloshing" effect when dragged
    vec2 samplingCoord = coord + uWarpOffset * 0.15; 
    
    vec2 centeredCoord = coord - halfSize;
    float radius = uRadius;

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    // Initial base color with subtle adaptive lighting
    vec4 color = vec4(0.0);

    // If perfectly opaque center
    if (-sd >= uRefractionHeight) {
        color = texture(uImage, samplingCoord / uSize);
        color.rgb = saturateColor(color.rgb, 1.08);
    } else {
        // Refraction edge logic
        float dist = min(sd, 0.0);
        float d = circleMap(1.0 - -dist / uRefractionHeight) * uRefractionAmount;
        
        float smoothRadius = max(radius * 1.5, 30.0);
        float gradRadius = min(smoothRadius, min(halfSize.x, halfSize.y));
        vec2 grad = normalize(gradSdRoundedRect(centeredCoord, halfSize, gradRadius) + 0.3 * normalize(centeredCoord));

        vec2 refractedCoord = (samplingCoord + d * grad) / uSize;
        
        // 7-CHANNEL DISPERSION (Rainbow Edge)
        float dispersionScale = uDispersion * 0.25 * ((centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y));
        vec2 dispersedCoord = (d * grad * dispersionScale) / uSize;

        color.r += texture(uImage, refractedCoord + dispersedCoord).r / 3.5;
        color.a += texture(uImage, refractedCoord + dispersedCoord).a / 7.0;

        vec4 orange = texture(uImage, refractedCoord + dispersedCoord * (2.0 / 3.0));
        color.r += orange.r / 3.5; color.g += orange.g / 7.0; color.a += orange.a / 7.0;

        vec4 yellow = texture(uImage, refractedCoord + dispersedCoord * (1.0 / 3.0));
        color.r += yellow.r / 3.5; color.g += yellow.g / 3.5; color.a += yellow.a / 7.0;

        vec4 green = texture(uImage, refractedCoord);
        color.g += green.g / 3.5; color.a += green.a / 7.0;

        vec4 cyan = texture(uImage, refractedCoord - dispersedCoord * (1.0 / 3.0));
        color.g += cyan.g / 3.5; color.b += cyan.b / 3.0; color.a += cyan.a / 7.0;

        vec4 blue = texture(uImage, refractedCoord - dispersedCoord * (2.0 / 3.0));
        color.b += blue.b / 3.0; color.a += blue.a / 7.0;

        vec4 purple = texture(uImage, refractedCoord - dispersedCoord);
        color.r += purple.r / 7.0; color.b += purple.b / 3.0; color.a += purple.a / 7.0;
    }

    // ADAPTIVE TOUCH GLOW (The missing magic)
    if (uGlowIntensity > 0.0) {
        float glowDist = distance(coord, uGlowPos);
        float glowArea = uSize.x * 0.4 * uGlowIntensity; 
        float glowFalloff = 1.0 - smoothstep(0.0, glowArea, glowDist);
        
        // Add frosted white highlights that follow the finger
        color.rgb += vec3(glowFalloff * 0.12); 
    }

    // Final Post-Process
    color.rgb = saturateColor(color.rgb, 1.15);
    color.rgb = (color.rgb - 0.5) * 1.05 + 0.5;
    
    // Apply Configurable Tint
    color.rgb = mix(color.rgb, uTintColor, uTintAlpha);
    
    fragColor = color;
}