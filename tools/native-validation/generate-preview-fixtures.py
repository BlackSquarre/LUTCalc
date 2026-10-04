"""生成仅用于研发验证的 8/16 位 PNG；不进入原生 App。"""

import argparse
import struct
import zlib
from pathlib import Path


def chunk(kind: bytes, content: bytes) -> bytes:
    return (struct.pack(">I", len(content)) + kind + content
            + struct.pack(">I", zlib.crc32(kind + content) & 0xFFFFFFFF))


def image(depth: int, color_type: int, pixels: list[tuple[int, ...]],
          embedded_icc: bytes | None = None) -> bytes:
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    code = "B" if depth == 8 else "H"
    row = b"\0" + b"".join(struct.pack(">" + code * channels, *pixel) for pixel in pixels)
    header = struct.pack(">IIBBBBB", len(pixels), 1, depth, color_type, 0, 0, 0)
    icc_chunk = (chunk(b"iCCP", b"LUTCalc fixture sRGB\0\0" + zlib.compress(embedded_icc))
                 if embedded_icc is not None else b"")
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + icc_chunk
            + chunk(b"IDAT", zlib.compress(row)) + chunk(b"IEND", b""))


def oversized_header_png() -> bytes:
    header = struct.pack(">IIBBBBB", 5000, 5000, 8, 6, 0, 0, 0)
    compressor = zlib.compressobj(level=1)
    row = b"\0" * (1 + 5000 * 4)
    payload = b"".join(compressor.compress(row) for _ in range(5000)) + compressor.flush()
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", payload) + chunk(b"IEND", b""))


def tiff16(orientation: int, pixels: list[tuple[int, ...]], width: int, height: int,
           associated_alpha: bool = False) -> bytes:
    raster = b"".join(struct.pack("<HHHH", *pixel) for pixel in pixels)
    tags = [
        (256, 4, 1, width), (257, 4, 1, height), (258, 3, 4, 0),
        (259, 3, 1, 1), (262, 3, 1, 2), (273, 4, 1, 0),
        (274, 3, 1, orientation), (277, 3, 1, 4), (278, 4, 1, height),
        (279, 4, 1, len(raster)), (284, 3, 1, 1), (338, 3, 1, 1 if associated_alpha else 2),
    ]
    bits_offset = 8 + 2 + 12 * len(tags) + 4
    raster_offset = bits_offset + 8
    tags = [(tag, kind, count, bits_offset if tag == 258 else
             raster_offset if tag == 273 else value)
            for tag, kind, count, value in tags]
    ifd = struct.pack("<H", len(tags))
    ifd += b"".join(struct.pack("<HHII", *tag) for tag in tags)
    ifd += struct.pack("<I", 0)
    return b"II" + struct.pack("<HI", 42, 8) + ifd + struct.pack("<HHHH", 16, 16, 16, 16) + raster


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    directory = parser.parse_args().directory
    directory.mkdir(parents=True, exist_ok=False)
    profile_path = Path("/System/Library/ColorSync/Profiles/sRGB Profile.icc")
    if not profile_path.is_file():
        raise RuntimeError("缺少 macOS 系统 sRGB ICC，不能构造嵌入 ICC 的测试夹具")
    embedded_icc = profile_path.read_bytes()
    two_pixels = [(0, 16384, 32768, 65535), (65535, 32768, 16384, 32768)]
    orientation_pixels = [(1000 * index, 0, 0, 65535) for index in range(1, 7)]
    fixtures = {
        "rgba8.png": image(8, 6, [(0, 64, 128, 255), (255, 128, 64, 128)]),
        "rgba8-embedded-icc.png": image(8, 6, [(0, 64, 128, 255), (255, 128, 64, 128)],
                                            embedded_icc),
        "rgba16.png": image(16, 6, [(0, 16384, 32768, 65535),
                                      (65535, 32768, 16384, 32768)]),
        "rgb8.png": image(8, 2, [(1, 2, 3), (254, 253, 252)]),
        "gray8.png": image(8, 0, [(32,), (224,)]),
        "gray16.png": image(16, 0, [(16384,), (49152,)]),
        "gray8-alpha.png": image(8, 4, [(64, 128), (192, 255)]),
        "oversized-header.png": oversized_header_png(),
        "rgba16.tiff": tiff16(1, two_pixels, 2, 1),
        "rgba16-rotated.tiff": tiff16(6, two_pixels, 2, 1),
        "premultiplied16.tiff": tiff16(1, [(0, 0, 0, 65535),
                                              (32768, 0, 0, 32768)], 2, 1, associated_alpha=True),
    }
    for orientation in range(1, 9):
        fixtures[f"orientation-{orientation}.tiff"] = tiff16(
            orientation, orientation_pixels, 2, 3)
    for name, content in fixtures.items():
        (directory / name).write_bytes(content)
    print(f"独立图像夹具已生成：{directory}，RGB/灰度 PNG 8/16 位（含嵌入 ICC）、TIFF 16 位及方向 1–8")


if __name__ == "__main__":
    main()
