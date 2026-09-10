#!/usr/bin/env python3
"""
remove_chroma_key.py — 単色背景(クロマキー)を透過に変換する。

Codex imagegen(gpt-image-2)は透過PNGを直接出力できないため、
「背景を単色(既定 #FF00FF マゼンタ)で塗る」よう STYLE/AVOID ブロックで指定して
生成し、本スクリプトで背景色をアルファ0(透明)に置き換える。

使い方:
    python3 remove_chroma_key.py <input.png> <output.png> [--color FF00FF] [--tolerance 40]

要件: Pillow (pip install Pillow)
"""
import argparse
import sys

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow が必要です。`pip install Pillow` を実行してください。", file=sys.stderr)
    sys.exit(1)


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    if len(hex_color) != 6:
        raise ValueError(f"不正なカラーコード: {hex_color}")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4))


def remove_chroma_key(input_path: str, output_path: str, key_hex: str, tolerance: int) -> int:
    key_r, key_g, key_b = hex_to_rgb(key_hex)
    img = Image.open(input_path).convert("RGBA")
    pixels = img.load()
    width, height = img.size
    removed = 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if (
                abs(r - key_r) <= tolerance
                and abs(g - key_g) <= tolerance
                and abs(b - key_b) <= tolerance
            ):
                pixels[x, y] = (r, g, b, 0)
                removed += 1

    img.save(output_path)
    return removed


def main() -> None:
    parser = argparse.ArgumentParser(description="単色背景(クロマキー)を透過に変換する")
    parser.add_argument("input", help="入力PNG(単色背景で生成した画像)")
    parser.add_argument("output", help="出力PNG(透過)")
    parser.add_argument("--color", default="FF00FF", help="クロマキー色(既定: FF00FF マゼンタ)")
    parser.add_argument("--tolerance", type=int, default=40, help="色の許容誤差(既定: 40)")
    args = parser.parse_args()

    removed = remove_chroma_key(args.input, args.output, args.color, args.tolerance)
    total = None
    try:
        with Image.open(args.input) as im:
            total = im.size[0] * im.size[1]
    except Exception:
        pass

    if total:
        print(f"透過化したピクセル数: {removed} / {total} ({removed / total:.1%})")
    else:
        print(f"透過化したピクセル数: {removed}")
    print(f"出力: {args.output}")
    print("必ず生成物を開いて、輪郭のフリンジ(縁取りの色残り)や誤消去(意図した色の欠落)が無いか確認すること。")


if __name__ == "__main__":
    main()
