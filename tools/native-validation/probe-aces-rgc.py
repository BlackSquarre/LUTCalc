#!/usr/bin/env python3
"""Independent Decimal reference for ACES 1.3 Reference Gamut Compression."""
from decimal import Decimal, getcontext
import json
import sys

getcontext().prec = 90
D = Decimal

TRA1 = (
    (D("1.4514393161"), D("-0.2365107469"), D("-0.2149285693")),
    (D("-0.0765537734"), D("1.1762296998"), D("-0.0996759264")),
    (D("0.0083161484"), D("-0.0060324498"), D("0.9977163014")),
)
TRA2 = (
    (D("0.6954522414"), D("0.1406786965"), D("0.1638690622")),
    (D("0.0447945634"), D("0.8596711185"), D("0.0955343182")),
    (D("-0.0055258826"), D("0.0040252103"), D("1.0015006723")),
)
LIMITS = (D("1.147"), D("1.264"), D("1.312"))
THRESHOLDS = (D("0.815"), D("0.803"), D("0.880"))
P = D("1.2")


def matrix(matrix_value, vector):
    return tuple(sum(matrix_value[row][column] * vector[column] for column in range(3)) for row in range(3))


def power(value, exponent):
    if value == 0:
        return D(0)
    return (exponent * value.ln()).exp()


def compress_distance(distance, threshold, limit):
    if distance < threshold:
        return distance
    scale = (limit - threshold) / power(power((D(1) - threshold) / (limit - threshold), -P) - D(1), D(1) / P)
    d_power = power((distance - threshold) / scale, P)
    return threshold + (distance - threshold) / power(D(1) + d_power, D(1) / P)


def compress(rgb):
    ap1 = matrix(TRA1, rgb)
    achromatic = max(ap1)
    if achromatic == 0:
        distances = (D(0), D(0), D(0))
    else:
        distances = tuple((achromatic - value) / abs(achromatic) for value in ap1)
    compressed = tuple(
        achromatic - compress_distance(distances[index], THRESHOLDS[index], LIMITS[index]) * abs(achromatic)
        for index in range(3)
    )
    return matrix(TRA2, compressed)


def decompress_distance(distance, threshold, limit):
    if distance < threshold:
        return distance
    scale = (limit - threshold) / power(power((D(1) - threshold) / (limit - threshold), -P) - D(1), D(1) / P)
    if distance > threshold + scale:
        return distance
    normalized = (distance - threshold) / scale
    powered = power(normalized, P)
    if powered >= D(1):
        raise ArithmeticError("inverse singularity")
    return threshold + scale * power(powered / (D(1) - powered), D(1) / P)


def decompress(rgb):
    ap1 = matrix(TRA1, rgb)
    achromatic = max(ap1)
    if achromatic == 0:
        distances = (D(0), D(0), D(0))
    else:
        distances = tuple((achromatic - value) / abs(achromatic) for value in ap1)
    expanded = tuple(
        decompress_distance(distances[index], THRESHOLDS[index], LIMITS[index])
        for index in range(3)
    )
    return matrix(TRA2, tuple(achromatic - value * abs(achromatic) for value in expanded))


def decimal_vector(values):
    return [format(value, "f") for value in values]


def main():
    # The grid is an independent stress set, not an embedded product resource.
    points = []
    for size in (3, 5, 17):
        denominator = D(size - 1)
        for r in range(size):
            for g in range(size):
                for b in range(size):
                    points.append(tuple(D(index) / denominator * D("2") - D("0.5") for index in (r, g, b)))
    points.extend(
        (
            (D("1.2"), D("-0.1"), D("0.05")),
            (D("0.18"), D("0.18"), D("0.18")),
            (D("-1"), D("0"), D("1")),
            (D("2"), D("-0.5"), D("0.25")),
        )
    )
    values = [{"input": decimal_vector(point), "output": decimal_vector(compress(point))} for point in points]
    inverse_values = [
        {"input": decimal_vector(compress(point)), "output": decimal_vector(decompress(compress(point)))}
        for point in points
    ]
    print(json.dumps({
        "algorithm": "aces.reference-gamut-compression-1.3.0",
        "precision": 90,
        "sampleCount": len(values),
        "samples": values,
        "inverseSamples": inverse_values,
    }, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ArithmeticError, ValueError) as error:
        print(f"probe-aces-rgc.py: {error}", file=sys.stderr)
        raise
