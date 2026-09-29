"""Emit the Swift reference rig from the checked-in extracted motion data."""

from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[3]
data = json.loads((ROOT / "Design/FlameMotion/reference-rig.json").read_text())
lines = [
    "// Generated from Design/FlameMotion/reference-rig.json.\n"
    "// Inverse TPS mappings transfer the committed 16-frame gait to approved artwork.\n"
    "import Foundation\n\n"
    "struct FlameReferencePose {\n"
    "    let faceRotation: Double\n"
    "    let faceScale: CGFloat\n"
    "    let mapping: [Float]\n"
    "}\n\n"
    "enum FlameReferenceRig {\n"
    f"    static let controlCount = {data['controlCount']}\n"
    "    static let frames: [FlameReferencePose] = ["
]
for frame in data["frames"]:
    index = frame["frame"]
    scale = 0.82 if 8 <= index <= 10 else 0.90 if 11 <= index <= 12 else 1.0
    mapping = ", ".join(f"{value:.9f}" for value in frame["mapping"])
    lines.append(
        f"        .init(faceRotation: {frame['rotation']}, faceScale: {scale:.2f}, mapping: [{mapping}]),"
    )
lines.append("    ]\n}\n")
(ROOT / "Whisper/FlameReferenceRig.swift").write_text("\n".join(lines))
print("Emitted 16 reference poses")
