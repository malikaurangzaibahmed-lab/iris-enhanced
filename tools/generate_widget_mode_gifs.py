from __future__ import annotations

import math
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
DRAWABLE = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable"
ASSETS = ROOT / "assets"

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def hex_to_rgba(value: str, alpha_override: int | None = None) -> tuple[int, int, int, int]:
    v = value.strip().lstrip("#")
    if len(v) == 6:
        r = int(v[0:2], 16)
        g = int(v[2:4], 16)
        b = int(v[4:6], 16)
        a = 255
    elif len(v) == 8:
        a = int(v[0:2], 16)
        r = int(v[2:4], 16)
        g = int(v[4:6], 16)
        b = int(v[6:8], 16)
    else:
        raise ValueError(f"Unsupported color format: {value}")
    if alpha_override is not None:
        a = alpha_override
    return (r, g, b, a)


def read_light_gradient() -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    xml_path = DRAWABLE / "widget_fluffy_bg.xml"
    root = ET.parse(xml_path).getroot()
    gradient = root.find("gradient")
    if gradient is None:
        return hex_to_rgba("#FFFFFF"), hex_to_rgba("#F5F7FE")
    start = gradient.attrib.get(f"{ANDROID_NS}startColor", "#FFFFFF")
    end = gradient.attrib.get(f"{ANDROID_NS}endColor", "#F5F7FE")
    return hex_to_rgba(start), hex_to_rgba(end)


def read_dark_solid() -> tuple[int, int, int, int]:
    xml_path = DRAWABLE / "widget_fluffy_dark_bg.xml"
    root = ET.parse(xml_path).getroot()
    solid = root.find("solid")
    if solid is None:
        return hex_to_rgba("#1A1A24")
    color = solid.attrib.get(f"{ANDROID_NS}color", "#1A1A24")
    return hex_to_rgba(color)


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    base = Image.new("RGBA", size)
    draw = ImageDraw.Draw(base)
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        a = int(top[3] + (bottom[3] - top[3]) * t)
        draw.line((0, y, w, y), fill=(r, g, b, a))
    return base


def render_light_frame(size: tuple[int, int], phase: float, start: tuple[int, int, int, int], end: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    frame = vertical_gradient(size, start, end).convert("RGBA")
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    cx = int((0.12 + 0.74 * ((math.sin(phase) + 1) / 2)) * w)
    cy = int((0.18 + 0.24 * ((math.cos(phase * 0.8) + 1) / 2)) * h)
    r = int(min(w, h) * 0.58)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 102))

    accent_x = int((0.85 + 0.22 * math.sin(phase * 1.3)) * w) % (w + 180) - 90
    draw.rounded_rectangle((accent_x, 18, accent_x + 160, h - 18), radius=34, fill=(116, 182, 255, 58))

    sheen_x = int((phase / (2 * math.pi)) * (w + 150)) - 150
    draw.rounded_rectangle((sheen_x, -16, sheen_x + 150, h + 16), radius=30, fill=(255, 255, 255, 54))

    warm_glow = Image.new("RGBA", size, (0, 0, 0, 0))
    wg = ImageDraw.Draw(warm_glow)
    wg.ellipse((w * 0.08, h * 0.56, w * 0.56, h * 1.08), fill=(255, 183, 77, 58))

    blur = overlay.filter(ImageFilter.GaussianBlur(16))
    frame.alpha_composite(warm_glow.filter(ImageFilter.GaussianBlur(18)))
    frame.alpha_composite(blur)
    return frame


def render_dark_frame(size: tuple[int, int], phase: float, base_color: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    top = (max(0, base_color[0] - 6), max(0, base_color[1] - 4), min(255, base_color[2] + 14), 255)
    bottom = (min(255, base_color[0] + 22), min(255, base_color[1] + 18), min(255, base_color[2] + 38), 255)
    frame = vertical_gradient(size, top, bottom).convert("RGBA")

    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    cx = int((0.18 + 0.64 * ((math.sin(phase * 0.9) + 1) / 2)) * w)
    cy = int((0.30 + 0.26 * ((math.cos(phase * 1.1) + 1) / 2)) * h)
    r = int(min(w, h) * 0.52)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(89, 127, 255, 74))

    accent_x = int((phase / (2 * math.pi)) * (w + 220)) - 220
    draw.rounded_rectangle((accent_x, 22, accent_x + 180, h - 22), radius=34, fill=(65, 105, 225, 52))

    sheen_x = int((phase / (2 * math.pi)) * (w + 170)) - 170
    draw.rounded_rectangle((sheen_x, -22, sheen_x + 170, h + 22), radius=34, fill=(180, 210, 255, 36))

    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((w * 0.56, h * 0.18, w * 1.06, h * 0.68), fill=(94, 140, 255, 50))

    vignette = Image.new("RGBA", size, (0, 0, 0, 0))
    vg = ImageDraw.Draw(vignette)
    vg.rounded_rectangle((0, 0, w - 1, h - 1), radius=34, outline=(255, 255, 255, 24), width=2)

    frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(20)))
    frame.alpha_composite(overlay.filter(ImageFilter.GaussianBlur(18)))
    frame.alpha_composite(vignette)
    return frame


def save_gif(frames: list[Image.Image], out_path: Path, duration_ms: int) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        out_path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )


def main() -> None:
    size = (720, 432)
    frame_count = 40
    duration = 56

    light_start, light_end = read_light_gradient()
    dark_base = read_dark_solid()

    light_frames: list[Image.Image] = []
    dark_frames: list[Image.Image] = []

    for i in range(frame_count):
        phase = (i / frame_count) * (2 * math.pi)
        light_frames.append(render_light_frame(size, phase, light_start, light_end).convert("P", palette=Image.ADAPTIVE, colors=256))
        dark_frames.append(render_dark_frame(size, phase, dark_base).convert("P", palette=Image.ADAPTIVE, colors=256))

    save_gif(light_frames, ASSETS / "widget_bg_light.gif", duration)
    save_gif(dark_frames, ASSETS / "widget_bg_dark.gif", duration)

    print("Generated:")
    print(ASSETS / "widget_bg_light.gif")
    print(ASSETS / "widget_bg_dark.gif")


if __name__ == "__main__":
    main()
