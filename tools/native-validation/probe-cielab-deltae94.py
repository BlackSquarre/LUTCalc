"""用独立 Decimal 参照计算 CIE94 图形艺术和纺织参数样例。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 90
D = Decimal


def delta_e94(first, second, application):
    l1, a1, b1 = map(D, first)
    l2, a2, b2 = map(D, second)
    c1 = (a1 * a1 + b1 * b1).sqrt()
    c2 = (a2 * a2 + b2 * b2).sqrt()
    delta_l = l2 - l1
    delta_c = c2 - c1
    delta_a = a2 - a1
    delta_b = b2 - b1
    delta_h2 = max(D(0), delta_a * delta_a + delta_b * delta_b - delta_c * delta_c)
    kl, k1, k2 = {
        "graphicArts": (D(1), D("0.045"), D("0.015")),
        "textiles": (D(2), D("0.048"), D("0.014")),
    }[application]
    lightness = delta_l / kl
    chroma = delta_c / (1 + k1 * c1)
    hue = delta_h2.sqrt() / (1 + k2 * c1)
    return (lightness * lightness + chroma * chroma + hue * hue).sqrt()


first = ("50", "2.6772", "-79.7751")
second = ("50", "0", "-82.7485")
print(json.dumps({
    "precision": getcontext().prec,
    "graphicArts": format(delta_e94(first, second, "graphicArts"), "f"),
    "textiles": format(delta_e94(first, second, "textiles"), "f"),
}, ensure_ascii=False, indent=2))
