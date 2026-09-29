"""Split the approved joy PNG into a deformable body and a rigid face.

The two generated layers composite back to the approved source image.  The
body fills the face marks with the existing inner-flame color so the face can
rotate and scale without exposing holes.
"""

from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "Design/EmotionFlames/Approved/joy.png"
ASSETS = ROOT / "Whisper/Assets.xcassets"
INNER = (255, 212, 119)
INK = (41, 37, 42)


def contents(filename: str) -> dict:
    return {
        "images": [
            {"filename": filename, "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }


image = Image.open(SOURCE).convert("RGBA")
body = image.copy()
face = Image.new("RGBA", image.size, (0, 0, 0, 0))

# The approved face is the only dark artwork.  Recover its antialias coverage
# against the known inner-flame fill, then rebuild it as a transparent overlay.
denominator = sum((INNER[channel] - INK[channel]) ** 2 for channel in range(3))
for y in range(image.height):
    for x in range(image.width):
        red, green, blue, alpha = image.getpixel((x, y))
        if alpha == 0:
            continue
        projection = sum(
            (INNER[channel] - (red, green, blue)[channel])
            * (INNER[channel] - INK[channel])
            for channel in range(3)
        ) / denominator
        coverage = max(0.0, min(1.0, projection))
        reconstructed = tuple(
            INNER[channel] + (INK[channel] - INNER[channel]) * coverage
            for channel in range(3)
        )
        line_error = sum(
            ((red, green, blue)[channel] - reconstructed[channel]) ** 2
            for channel in range(3)
        ) ** 0.5
        # Restrict the split to the lower-center face region so body edges and
        # outer antialiasing remain byte-for-byte inherited from the source.
        in_face_region = 0.20 < x / image.width < 0.82 and 0.48 < y / image.height < 0.88
        if in_face_region and coverage > 0.025 and line_error < 18:
            face.putpixel((x, y), (*INK, round(255 * coverage * alpha / 255)))
            body.putpixel((x, y), (*INNER, alpha))

for asset_name, layer in (("EmotionFlameJoyBody", body), ("EmotionFlameJoyFace", face)):
    directory = ASSETS / f"{asset_name}.imageset"
    directory.mkdir(parents=True, exist_ok=True)
    filename = f"{asset_name}.png"
    layer.save(directory / filename)
    (directory / "Contents.json").write_text(
        json.dumps(contents(filename), ensure_ascii=False, indent=2) + "\n"
    )

print("Generated deterministic joy body and face layers from", SOURCE)
