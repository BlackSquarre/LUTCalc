"""用独立 Decimal 数学参照计算公开 CIEDE2000 样例。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 90
D = Decimal
PI = D("3.141592653589793238462643383279502884197169399375105820974944592307816406286")
TWO_PI = 2 * PI


def sin_decimal(value: Decimal) -> Decimal:
    value = (value + PI) % TWO_PI - PI
    term = value
    total = term
    for n in range(1, 90):
        term *= -value * value / D((2 * n) * (2 * n + 1))
        total += term
        if abs(term) < D("1e-88"):
            break
    return total


def cos_decimal(value: Decimal) -> Decimal:
    return sin_decimal(value + PI / 2)


def atan_decimal(value: Decimal) -> Decimal:
    if value == 0:
        return D(0)
    sign = D(-1) if value < 0 else D(1)
    value = abs(value)
    if value > 1:
        return sign * (PI / 2 - atan_decimal(1 / value))
    # Half-angle reduction keeps the alternating series rapidly convergent.
    if value > D("0.5"):
        reduced = value / (1 + (1 + value * value).sqrt())
        return sign * 2 * atan_decimal(reduced)
    term = value
    total = term
    square = value * value
    for n in range(1, 180):
        term *= -square
        add = term / D(2 * n + 1)
        total += add
        if abs(add) < D("1e-88"):
            break
    return sign * total


def atan2_decimal(y: Decimal, x: Decimal) -> Decimal:
    if x > 0:
        return atan_decimal(y / x)
    if x < 0 and y >= 0:
        return atan_decimal(y / x) + PI
    if x < 0 and y < 0:
        return atan_decimal(y / x) - PI
    if x == 0 and y > 0:
        return PI / 2
    if x == 0 and y < 0:
        return -PI / 2
    return D(0)


def hue(a: Decimal, b: Decimal, chroma: Decimal) -> Decimal:
    if chroma == 0:
        return D(0)
    result = atan2_decimal(b, a) * 180 / PI
    return result if result >= 0 else result + 360


def ciede2000(first, second):
    l1, a1, b1 = map(D, first)
    l2, a2, b2 = map(D, second)
    c1 = (a1 * a1 + b1 * b1).sqrt()
    c2 = (a2 * a2 + b2 * b2).sqrt()
    mean_c = (c1 + c2) / 2
    twenty_five_7 = D(25) ** 7
    mean_c_7 = mean_c ** 7
    g = (D("0.5") * (1 - (mean_c_7 / (mean_c_7 + twenty_five_7)).sqrt()))
    a1p = (1 + g) * a1
    a2p = (1 + g) * a2
    c1p = (a1p * a1p + b1 * b1).sqrt()
    c2p = (a2p * a2p + b2 * b2).sqrt()
    h1p = hue(a1p, b1, c1p)
    h2p = hue(a2p, b2, c2p)
    dl = l2 - l1
    dc = c2p - c1p
    product = c1p * c2p
    if product == 0:
        dh = D(0)
    else:
        raw = h2p - h1p
        dh = raw if abs(raw) <= 180 else (raw - 360 if raw > 180 else raw + 360)
    d_big_h = 2 * product.sqrt() * sin_decimal(dh * PI / 360)
    mean_l = (l1 + l2) / 2
    mean_cp = (c1p + c2p) / 2
    if product == 0:
        mean_h = h1p + h2p
    else:
        raw = h1p + h2p
        difference = abs(h1p - h2p)
        mean_h = raw / 2 if difference <= 180 else ((raw + 360) / 2 if raw < 360 else (raw - 360) / 2)
    mean_h_radians = mean_h * PI / 180
    t = (1 - D("0.17") * cos_decimal(mean_h_radians - 30 * PI / 180)
         + D("0.24") * cos_decimal(2 * mean_h_radians)
         + D("0.32") * cos_decimal(3 * mean_h_radians + 6 * PI / 180)
         - D("0.20") * cos_decimal(4 * mean_h_radians - 63 * PI / 180))
    delta_theta = 30 * (-((mean_h - 275) / 25) ** 2).exp()
    rc = 2 * (mean_cp ** 7 / (mean_cp ** 7 + twenty_five_7)).sqrt()
    sl = 1 + D("0.015") * (mean_l - 50) ** 2 / (20 + (mean_l - 50) ** 2).sqrt()
    sc = 1 + D("0.045") * mean_cp
    sh = 1 + D("0.015") * mean_cp * t
    rt = -sin_decimal(2 * delta_theta * PI / 180) * rc
    lightness = dl / sl
    chroma = dc / sc
    hue_term = d_big_h / sh
    return (lightness * lightness + chroma * chroma + hue_term * hue_term + rt * chroma * hue_term).sqrt()


PAIRS = [
    (("50", "2.6772", "-79.7751"), ("50", "0", "-82.7485")),
    (("50", "3.1571", "-77.2803"), ("50", "0", "-82.7485")),
    (("50", "2.8361", "-74.0200"), ("50", "0", "-82.7485")),
    (("50", "-1.3802", "-84.2814"), ("50", "0", "-82.7485")),
]

results = [{"first": first, "second": second, "deltaE2000": format(ciede2000(first, second), "f")} for first, second in PAIRS]
print(json.dumps({"precision": getcontext().prec, "results": results}, ensure_ascii=False, indent=2))
