#include <metal_stdlib>
using namespace metal;

static float thinPlateRadial(float2 delta) {
    float radiusSquared = dot(delta, delta);
    return 0.5f * radiusSquared * log(max(radiusSquared, 1e-12f));
}

// The committed GitHub gait stores an inverse thin-plate-spline mapping for
// each of its 16 frames.  Apply it only to the body layer; the approved face is
// rendered separately and receives the original rigid rotation/scale.
[[ stitchable ]] float2 flameReferenceWarp(
    float2 position,
    float4 bounds,
    device const float *mapping,
    int count,
    float blend
) {
    if (count < 10 || bounds.z <= 0.0f || bounds.w <= 0.0f || blend <= 0.0f) {
        return position;
    }

    float2 target = (position - bounds.xy) / bounds.zw;
    int controlCount = (count - 6) / 4;
    int affine = controlCount * 4;
    float2 source = float2(mapping[affine], mapping[affine + 1]);
    source += target.x * float2(mapping[affine + 2], mapping[affine + 3]);
    source += target.y * float2(mapping[affine + 4], mapping[affine + 5]);

    for (int index = 0; index < controlCount; ++index) {
        int offset = index * 4;
        float2 control = float2(mapping[offset], mapping[offset + 1]);
        float2 weight = float2(mapping[offset + 2], mapping[offset + 3]);
        source += weight * thinPlateRadial(target - control);
    }
    return mix(position, bounds.xy + source * bounds.zw, clamp(blend, 0.0f, 1.0f));
}

// Work on the approved, flattened PNG without sampling a different texture.
// The face lies in the middle of the body: the crown ends before it, and the
// foot starts below it. Neither the eyes nor mouth receive a non-rigid warp.
[[ stitchable ]] float2 flameBodyWarp(
    float2 position, float4 bounds, float3 motion
) {
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
