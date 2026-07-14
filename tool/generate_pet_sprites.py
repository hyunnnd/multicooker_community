import json
from pathlib import Path

from PIL import Image, ImageDraw

FRAME = 32
SCALE = 3
OUT = Path(__file__).resolve().parents[1] / "assets/images/pet"
TOQUE_OUT = OUT / "toque"

BLUE_LIGHT = (155, 202, 244, 255)
BLUE = (55, 138, 221, 255)
ORANGE = (255, 122, 0, 255)
ORANGE_THINK = (242, 110, 0, 255)
ORANGE_WAIT = (229, 110, 0, 255)
ERROR = (217, 76, 55, 255)
SLEEP_BLUE = (113, 166, 226, 255)
DARK = (41, 41, 41, 255)
WHITE = (255, 255, 245, 255)
GREY = (201, 197, 188, 255)
GREY_DARK = (156, 148, 132, 255)
YELLOW = (255, 205, 74, 255)
WOOD = (170, 124, 76, 255)
HAT_OUTLINE = (138, 122, 99, 255)


def darker(color):
    r, g, b, a = color
    return (max(0, r - 34), max(0, g - 28), max(0, b - 18), a)


def body_points(top, bottom, x=0):
    return [
        (16 + x, top),
        (12 + x, top + 1),
        (10 + x, top + 4),
        (8 + x, top + 10),
        (8 + x, top + 13),
        (10 + x, bottom - 1),
        (12 + x, bottom),
        (20 + x, bottom),
        (22 + x, bottom - 1),
        (24 + x, top + 13),
        (24 + x, top + 10),
        (22 + x, top + 4),
        (20 + x, top + 1),
    ]



def body(draw, color, y=0, x=0, eyes="open", squish=0, eye_y=0):
    top, bottom = 12 + y + squish, 29 + y
    draw.polygon(body_points(top - 1, bottom, x), fill=darker(color))
    draw.polygon(body_points(top, bottom - 1, x), fill=color)
    if eyes == "closed":
        draw.rectangle((11 + x, 23 + y + eye_y, 13 + x, 23 + y + eye_y), fill=DARK)
        draw.rectangle((19 + x, 23 + y + eye_y, 21 + x, 23 + y + eye_y), fill=DARK)
    elif eyes == "happy":
        for eye_x in (10, 18):
            draw.line((eye_x + x, 24 + y, eye_x + 2 + x, 22 + y), fill=DARK)
            draw.line((eye_x + 2 + x, 22 + y, eye_x + 4 + x, 24 + y), fill=DARK)
    else:
        draw.rectangle((11 + x, 21 + y + eye_y, 12 + x, 22 + y + eye_y), fill=DARK)
        draw.rectangle((20 + x, 21 + y + eye_y, 21 + x, 22 + y + eye_y), fill=DARK)


def chef_hat(draw, y=0):
    draw.rounded_rectangle((9, 6 + y, 23, 14 + y), radius=3, fill=HAT_OUTLINE)
    draw.rounded_rectangle((11, 7 + y, 21, 12 + y), radius=2, fill=WHITE)
    draw.rectangle((10, 12 + y, 22, 16 + y), fill=HAT_OUTLINE)
    draw.rectangle((11, 12 + y, 21, 14 + y), fill=WHITE)
    draw.rectangle((11, 15 + y, 21, 15 + y), fill=ORANGE)
    draw.rectangle((12, 16 + y, 20, 16 + y), fill=(181, 104, 45, 255))


def sleep_hat(draw, y=0):
    draw.polygon([(9, 15 + y), (13, 7 + y), (23, 10 + y), (20, 16 + y)], fill=SLEEP_BLUE)
    draw.rectangle((9, 14 + y, 21, 16 + y), fill=WHITE)
    draw.ellipse((20, 8 + y, 23, 11 + y), fill=WHITE)


def sparkle(draw, x, y):
    draw.rectangle((x, y + 1, x + 4, y + 2), fill=YELLOW)
    draw.rectangle((x + 1, y, x + 2, y + 3), fill=YELLOW)


def render_idle(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    offsets = [0, 1, 0, 0]
    body(draw, ORANGE, y=offsets[frame])
    for x in (12, 16, 20):
        draw.ellipse((x, 8, x + 1, 9), fill=GREY)
    return image


def render_searching(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    body(draw, BLUE_LIGHT)
    points = [(15, 5), (18, 2), (22, 1), (25, 3), (27, 6), (28, 9)]
    for index, (x, y) in enumerate(points):
        draw.ellipse((x, y, x + 2, y + 2), fill=BLUE if index == frame else GREY)
    return image


def render_connecting(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    body(draw, BLUE)
    active = frame % 3
    for index, x in enumerate((12, 16, 20)):
        draw.ellipse((x, 8, x + 1, 9), fill=WHITE if index == active else GREY)
    return image


def render_connected(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    y = [1, 0, -1, 0][frame]
    body(draw, ORANGE, y=y)
    chef_hat(draw, y=y)
    if frame == 3:
        sparkle(draw, 24, 8)
    return image


def render_thinking(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    body(draw, ORANGE_THINK, eye_y=-1)
    chef_hat(draw)
    dots = [(27, 10, 1), (29, 7, 2), (28, 3, 3)]
    for index, (x, y, size) in enumerate(dots):
        if index <= frame % 3:
            draw.ellipse((x, y, x + size, y + size), fill=GREY)
    return image


def render_cooking(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    y = [0, 1, 0, -1, 0, 1, 0, -1][frame]
    body(draw, ORANGE, y=y)
    spoon_x = [24, 25, 26, 25, 24, 23, 22, 23][frame]
    draw.line((spoon_x, 27, spoon_x + 3, 19), fill=WOOD, width=2)
    draw.ellipse((spoon_x + 2, 16, spoon_x + 5, 20), fill=WOOD)
    steam_y = 10 - (frame % 4)
    draw.ellipse((6, steam_y, 8, steam_y + 2), fill=GREY)
    draw.ellipse((9, steam_y + 3, 11, steam_y + 5), fill=GREY)
    chef_hat(draw, y=y)
    return image


def render_waiting(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    body(draw, ORANGE_WAIT)
    chef_hat(draw)
    draw.ellipse((26, 18, 31, 23), outline=GREY_DARK, width=1)
    draw.rectangle((28, 16, 29, 18), fill=GREY_DARK)
    hands = [(28, 19), (29, 20), (28, 22), (27, 20)][frame]
    draw.line((28, 20, hands[0], hands[1]), fill=ORANGE, width=1)
    return image


def render_success(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    y = [1, 0, -2, -1, 0, 1][frame]
    body(draw, ORANGE, y=y, eyes="happy")
    chef_hat(draw, y=y)
    if frame >= 1:
        sparkle(draw, 2, 7)
    if frame >= 3:
        sparkle(draw, 26, 9)
    if frame == 5:
        sparkle(draw, 3, 18)
    return image


def render_error(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    x = [-1, 1, -1, 1][frame]
    body(draw, ERROR, x=x)
    if frame % 2 == 0:
        draw.rectangle((27, 5, 28, 10), fill=ERROR)
        draw.rectangle((27, 12, 28, 13), fill=ERROR)
    return image


def render_sleeping(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    body(draw, SLEEP_BLUE, eyes="closed")
    sleep_hat(draw)
    z = [0, 1, 2, 3, 4, 5][frame]
    draw.text((25, 8 - z), "Z", fill=BLUE)
    if frame >= 3:
        draw.text((28, 4 - z), "z", fill=BLUE_LIGHT)
    return image


def render_tapped(frame):
    image = Image.new("RGBA", (FRAME, FRAME))
    draw = ImageDraw.Draw(image)
    body(draw, ORANGE, y=[0, 1, 2, 0][frame], squish=[0, 3, 2, 0][frame])
    chef_hat(draw, y=[0, 1, 2, 0][frame])
    if frame <= 2:
        sparkle(draw, 3, 7)
        sparkle(draw, 26, 8)
        sparkle(draw, 4, 21)
        sparkle(draw, 25, 22)
    return image


STATES = {
    "idle": (4, render_idle),
    "searching": (6, render_searching),
    "connecting": (6, render_connecting),
    "connected": (4, render_connected),
    "thinking": (6, render_thinking),
    "cooking": (8, render_cooking),
    "waiting": (4, render_waiting),
    "success": (6, render_success),
    "error": (4, render_error),
    "sleeping": (6, render_sleeping),
    "tapped": (4, render_tapped),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    TOQUE_OUT.mkdir(parents=True, exist_ok=True)
    for name, (count, renderer) in STATES.items():
        sheet = Image.new("RGBA", (FRAME * SCALE * count, FRAME * SCALE))
        for index in range(count):
            frame = renderer(index).resize(
                (FRAME * SCALE, FRAME * SCALE), Image.Resampling.NEAREST
            )
            sheet.alpha_composite(frame, (index * FRAME * SCALE, 0))
        sheet.save(OUT / f"{name}.png")

    atlas = Image.new("RGBA", (192 * 8, 208 * len(STATES)))
    for row, (name, (count, renderer)) in enumerate(STATES.items()):
        for col in range(8):
            frame = renderer(col % count).resize(
                (192, 192), Image.Resampling.NEAREST
            )
            atlas.alpha_composite(frame, (col * 192, row * 208 + 16))
    atlas.save(TOQUE_OUT / "spritesheet.webp", lossless=True)
    (TOQUE_OUT / "pet.json").write_text(
        json.dumps(
            {
                "id": "toque-cooking-pet",
                "displayName": "Toque",
                "description": "조리 기기 상태를 알려주는 요리 앱 전용 오렌지색 슬라임 셰프 마스코트",
                "spriteVersionNumber": 2,
                "spritesheetPath": "spritesheet.webp",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
