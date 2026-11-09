"""Writes the Locaproof icon SVGs: a white map pin with a check mark
(location + proof) on the app's brand blue."""
import sys

OUT = sys.argv[1]
BLUE_TOP, BLUE_BOTTOM = "#1488BA", "#07506F"
ACCENT = "#F5A524"

# Pin in a 1024 design space: head centre (512,430) r=240, tip (512,830).
PIN = "M512 838 C470 780 360 650 320 574 A240 240 0 1 1 704 574 C664 650 554 780 512 838 Z"
DISK = '<circle cx="512" cy="430" r="150"/>'
CHECK = "M447 434 L494 481 L582 389"


def pin(scale, dx, dy, mono=False, color="#fff", shadow=True):
    t = f'transform="translate({dx} {dy}) scale({scale})"'
    if mono:
        # One colour: pin with the disk cut out and the check inside.
        hole = "M512 280 A150 150 0 1 0 512.01 280 Z"
        return (f'<g {t}><path d="{PIN} {hole}" fill="#fff" fill-rule="evenodd"/>'
                f'<path d="{CHECK}" fill="none" stroke="#fff" stroke-width="46" '
                f'stroke-linecap="round" stroke-linejoin="round"/></g>')
    return (f'<g {t}>'
            + (f'<ellipse cx="512" cy="858" rx="120" ry="26" fill="#000" fill-opacity="0.18"/>'
               if shadow else '')
            + f'<path d="{PIN}" fill="{color}"/>'
            f'<g fill="{ACCENT}">{DISK}</g>'
            f'<path d="{CHECK}" fill="none" stroke="#fff" stroke-width="46" '
            f'stroke-linecap="round" stroke-linejoin="round"/></g>')


def bg(size):
    return (f'<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{BLUE_TOP}"/>'
            f'<stop offset="1" stop-color="{BLUE_BOTTOM}"/></linearGradient></defs>'
            f'<rect width="{size}" height="{size}" fill="url(#g)"/>')


def svg(size, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">{body}</svg>')


def centered(size, height_share):
    # Pin (with shadow) spans y 190..884 in design space: 694 tall.
    s = size * height_share / 694
    return s, size / 2 - 512 * s, size / 2 - 537 * s


files = {}
# Full square (iOS and store icon): no transparency.
s, dx, dy = centered(1024, 0.70)
files["full.svg"] = svg(1024, bg(1024) + pin(s, dx, dy))
# Adaptive layers on a 432 canvas (108dp); the safe circle is 66dp.
s, dx, dy = centered(432, 0.56)
files["foreground.svg"] = svg(432, pin(s, dx, dy))
files["monochrome.svg"] = svg(432, pin(s, dx, dy, mono=True))
files["background.svg"] = svg(432, bg(432))
# Splash logo: a blue pin, readable on light and dark backgrounds.
s, dx, dy = centered(1024, 0.92)
files["logo.svg"] = svg(1024, pin(s, dx, dy, color="#0B6E99", shadow=False))

for name, text in files.items():
    with open(f"{OUT}/{name}", "w") as f:
        f.write(text)
