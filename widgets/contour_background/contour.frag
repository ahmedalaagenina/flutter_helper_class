// Topographic contour field, drawn behind ContourBackground
// (contour_background.dart, next to this file).
//
// A smooth height field drifts slowly over time; contour lines are drawn
// where the height crosses evenly spaced levels. The pointer raises a hill,
// so lines bunch up and glow around the cursor (or finger).
//
// Line width is kept ~1px everywhere by dividing the distance to the nearest
// level by the local gradient (a numeric derivative, because runtime-effect
// shaders don't get dFdx/fwidth).
//
// Every time frequency in terrain() is a multiple of 0.01 rad/s, so the field
// repeats exactly every 200*pi seconds. The Dart side wraps uTime at that
// period: float precision stays high and the wrap is invisible.
//
// The Dart side sets the uniforms by index, in the order declared below
// (vec2 = 2 floats, vec4 = 4). Change both files together.
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;        // canvas size, logical px
uniform float uTime;       // seconds, wrapped at 200*pi on the Dart side
uniform vec2 uPointer;     // hill centre (live pointer or idle wanderer), px
uniform float uPresence;   // 0..1, how strongly the hill shapes the field
uniform vec4 uBg;          // background color, straight (not premultiplied)
uniform vec4 uLine;        // contour color; its alpha scales uLineAlpha
uniform vec4 uGlow;        // accent near the pointer; its alpha scales the glow
uniform float uLineAlpha;  // base contour opacity
uniform float uLevels;     // contour lines per unit of height (density)
uniform float uFadeTop;    // top fade, fraction of the height (0 = none)
uniform float uFadeBottom; // bottom fade, fraction of the height (0 = none)

out vec4 fragColor;

float terrain(vec2 p, float t) {
  float v = 0.55 * sin(p.x * 1.15 + t * 0.21 + sin(p.y * 0.7 + t * 0.13) * 1.2);
  v += 0.45 * sin(p.y * 1.35 - t * 0.17 + sin(p.x * 0.9 - t * 0.11) * 1.1);
  v += 0.20 * sin((p.x - p.y) * 2.1 + t * 0.29);
  v += 0.12 * sin(length(p - vec2(2.2, 1.4)) * 3.2 - t * 0.37);
  return v;
}

float heightAt(vec2 p, vec2 m, float t) {
  vec2 d = p - m;
  return terrain(p, t) + exp(-dot(d, d) * 2.2) * 0.85 * uPresence;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float shortSide = min(uSize.x, uSize.y);
  float unit = 3.2 / shortSide; // map units per logical pixel
  vec2 p = frag * unit;
  vec2 m = uPointer * unit;

  float h = heightAt(p, m, uTime);
  float hx = heightAt(p + vec2(unit, 0.0), m, uTime);
  float hy = heightAt(p + vec2(0.0, unit), m, uTime);
  float gradient = length(vec2(hx - h, hy - h)) * uLevels; // levels per px

  float level = h * uLevels;
  float distLevels = abs(fract(level + 0.5) - 0.5);
  float distPx = distLevels / max(gradient, 0.0001);

  // Every 5th contour is an "index contour", drawn heavier, as on real maps.
  float isIndex = 1.0 - step(0.5, mod(floor(level + 0.5), 5.0));
  float halfWidth = mix(0.55, 1.05, isIndex);
  float line = 1.0 - smoothstep(halfWidth, halfWidth + 1.0, distPx);

  vec2 dp = (frag - uPointer) / shortSide;
  float near = exp(-dot(dp, dp) * 18.0) * uPresence * uGlow.a;

  // Optional fades at the top and bottom edges (e.g. so a hero melts into
  // the page below). smoothstep is undefined when edge0 >= edge1, so the
  // bottom ramp is written as 1 - smoothstep, and a 0 fade becomes a tiny
  // ramp instead of a zero-width one (a division by zero).
  float y = frag.y / uSize.y;
  float edge = smoothstep(0.0, max(uFadeTop, 0.0001), y) *
      (1.0 - smoothstep(1.0 - max(uFadeBottom, 0.0001), 1.0, y));

  float alpha = line * uLineAlpha * uLine.a * mix(1.0, 1.9, isIndex) *
      (1.0 + near * 2.2);
  alpha = clamp(alpha * edge, 0.0, 1.0);

  // Lines over the background, output premultiplied as Flutter expects.
  // With an opaque background this is exactly mix(bg, line, alpha) + glow.
  vec3 lineColor = mix(uLine.rgb, uGlow.rgb, clamp(near * 1.4, 0.0, 1.0));
  float outAlpha = alpha + uBg.a * (1.0 - alpha);
  vec3 color = lineColor * alpha + uBg.rgb * (uBg.a * (1.0 - alpha));
  color += uGlow.rgb * (near * 0.035 * edge * outAlpha);
  fragColor = vec4(min(color, vec3(outAlpha)), outAlpha);
}
