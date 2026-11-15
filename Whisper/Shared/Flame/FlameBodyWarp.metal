#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Work on the approved, flattened PNG without sampling a different texture.
// The face lies in the middle of the body: the crown ends before it, and the
// foot starts below it. Neither the eyes nor mouth receive a non-rigid warp.
[[ stitchable ]] float2 flameBodyWarp(
    float2 position, float4 bounds, float3 motion
) {
    if (bounds.z <= 0.0f || bounds.w <= 0.0f) return position;
    float2 normalized = (position - bounds.xy) / bounds.zw;
    float crown = 1.0f - smoothstep(0.35f, 0.54f, normalized.y);
    float foot = smoothstep(0.84f, 0.96f, normalized.y);
    float sourceX = position.x - bounds.z * (motion.x * crown + motion.y * foot);
    float hinge = bounds.y + bounds.w * 0.84f;
    float sourceY = position.y;
    if (position.y > hinge) {
        sourceY = hinge + (position.y - hinge) / max(0.8f, 1.0f - motion.z);
    }
    return float2(sourceX, sourceY);
}

// Closes an eye inside its ellipse only. Vacated pixels take the face colour between the eyes,
// so nearby brows are never stretched; a guard line keeps brows that overlap the eye intact.
static float browSide(float2 position, float4 guard) {
    float2 direction = guard.zw - guard.xy;
    if (dot(direction, direction) <= 0.0f) return 1.0f;
    float2 normal = normalize(float2(-direction.y, direction.x));
    if (normal.y < 0.0f) normal = -normal;
    return dot(position - guard.xy, normal);
}

static half4 blinkEye(float2 position, SwiftUI::Layer layer, half4 color,
                      float4 eye, float4 guard, float2 skinPoint, float scale) {
    float2 radius = eye.zw * 0.5f;
    if (radius.x <= 0.0f || radius.y <= 0.0f) return color;
    float2 center = eye.xy + radius;
    float2 offset = (position - center) / radius;
    float mask = (1.0f - smoothstep(1.0f, 1.06f, length(offset)))
        * smoothstep(-0.4f, 0.4f, browSide(position, guard));
    if (mask <= 0.0f) return color;
    float2 source = float2(position.x, center.y + offset.y / max(scale, 0.08f) * radius.y);
    float2 sourceOffset = (source - center) / radius;
    bool isEye = dot(sourceOffset, sourceOffset) <= 1.0f && browSide(source, guard) > 0.0f;
    half4 closed = isEye ? layer.sample(source) : layer.sample(float2(skinPoint.x, center.y));
    return mix(color, closed, half(mask));
}

[[ stitchable ]] half4 flameBlink(
    float2 position, SwiftUI::Layer layer,
    float4 leftEye, float4 leftGuard, float4 rightEye, float4 rightGuard, float scale
) {
    half4 color = layer.sample(position);
    if (scale >= 1.0f) return color;
    float2 skinPoint = float2((leftEye.x + leftEye.z + rightEye.x) * 0.5f, 0.0f);
    color = blinkEye(position, layer, color, leftEye, leftGuard, skinPoint, scale);
    return blinkEye(position, layer, color, rightEye, rightGuard, skinPoint, scale);
}
