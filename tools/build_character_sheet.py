#!/usr/bin/env python3
"""Normalize a transparent horizontal character strip into ten 128px frames."""

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--frames", type=int, default=10)
    parser.add_argument("--frame-size", type=int, default=128)
    parser.add_argument("--columns", type=int, default=10)
    parser.add_argument("--rows", type=int, default=1)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    sheet = Image.new("RGBA", (args.frames * args.frame_size, args.frame_size))
    if args.columns * args.rows != args.frames:
        raise ValueError("columns * rows must equal frames")
    source_frame_width = source.width / args.columns
    source_frame_height = source.height / args.rows

    for index in range(args.frames):
        column = index % args.columns
        row = index // args.columns
        left = round(column * source_frame_width)
        right = round((column + 1) * source_frame_width)
        top = round(row * source_frame_height)
        bottom = round((row + 1) * source_frame_height)
        frame = source.crop((left, top, right, bottom))
        edge = max(2, round(min(frame.size) * 0.012))
        frame.paste((0, 0, 0, 0), (0, 0, edge, frame.height))
        frame.paste((0, 0, 0, 0), (frame.width - edge, 0, frame.width, frame.height))
        alpha_bounds = frame.getchannel("A").getbbox()
        if alpha_bounds is None:
            continue
        character = frame.crop(alpha_bounds)
        max_width = args.frame_size - 10
        max_height = args.frame_size - 8
        scale = min(max_width / character.width, max_height / character.height)
        size = (max(1, round(character.width * scale)), max(1, round(character.height * scale)))
        character = character.resize(size, Image.Resampling.LANCZOS)
        x = index * args.frame_size + (args.frame_size - character.width) // 2
        y = args.frame_size - character.height - 4
        sheet.alpha_composite(character, (x, y))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)


if __name__ == "__main__":
    main()
