#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] float2 flameFlex(float2 position, float2 size, float bend) {
    float depth = clamp(position.y / size.y, 0.0, 1.0);
    float lowerBody = smoothstep(0.24, 0.96, depth);
    lowerBody *= lowerBody;
    return float2(position.x - bend * lowerBody, position.y);
}
