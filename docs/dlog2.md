# DJI D-Log2 / D-Gamut2 support

Verified 2026-09-22. This implementation follows DJI's supplied ACES CTL IDT,
`urn:ampas:aces:transformId:v1.5:IDT.DJI.DLog2_DGamut2.a1.v1`.
It adds both encoding and decoding, input/output gamut matrices, manufacturer
filters, inline workers, and the shipped browser/fallback bundles.

## Use in LUTCalc

1. Select the **Generic** camera (available under any manufacturer), with Stop
   Correction **0**. Use the **All** Rec Gamma and Rec Gamut categories.
2. Set Rec Gamma to **DJI D-Log2**, Rec Gamut to **DJI D-Gamut2**.
3. Choose the required output gamma and gamut, then generate a 1D or 3D LUT.
   A 1D LUT transforms gamma only; a gamut conversion requires a 3D LUT.
   Both new selections are also available as outputs and under the DJI filters.
4. For a direct comparison with the supplied CTL/DCTL, use the native normalized
   signal: **109% / Data** input range in LUTCalc. This is the default preference
   of the new curve when the chosen LUT format permits it. In LUTCalc the 109%
   label means data range; it does not extend the cube domain beyond 0..1.
   A format preset can override the range preference, so check the range controls.
   **100% / Legal** instead applies the existing 64..940 range conversion.

The range selection describes numbers entering the LUT, not a claim about HEVC
container metadata or decoder behavior. The supplied documents do not specify
that metadata. Avoid applying an extra legal/full rescale if the application has
already performed it. The CTL maps a native normalized value of 312/1023 to 18%
grey; the equivalent legal-normalized coordinate is 248/876.

A Pocket 4P camera preset with ISO and measured sensor clipping stops is not
invented from the log equation. Generic avoids attaching another camera's ISO
behavior. Its chart clipping marker is a generic estimate, not a Pocket 4P
measurement. Likewise, the curve's mathematical maximum is not sensor dynamic
range. Change Hard Clip deliberately when retaining negative or HDR values.

## Evidence and cross-checks

- The supplied `Dlog2_DGamut2_to_ACES_AP0_cat02.ctl` gives the curve constants,
  primary chromaticities, D65 white and CAT02 adaptation to ACES AP0 (D60).
- The companion `DLog2_DGamut2_to_ACES_AP0_cat02.dctl` gives the same curve,
  but rounds the three color matrices to four decimal places. The maximum
  coefficient difference in their composed AP0 matrix is approximately
  **0.00010407187**. LUTCalc derives its matrix from the CTL primaries to preserve
  precision rather than reproducing those rounded matrices.
- `Recommended_ACES_Workflow_EN_2026.05.18.pdf` describes DCTL to linear AP0,
  followed by a separate ACES conversion to an AP1 grading space and a separate
  Rec.709 output transform. It is a workflow guide, not a second curve definition.
- The [user-provided Gamut article](https://gamut.io/white-paper-for-d-log2-and-d-gamut2-on-the-osmo-pocket-4p/)
  explicitly describes its white paper as unofficial and based on DJI's DCTL.
  The accessible article body did not expose an additional formula or a white
  paper download, so it is provenance context, not independent numeric evidence.
- The [DJI official size65 download](https://www.dji.com/cn/downloads/softwares/osmo-pocket-4p-dlog-2-to-rec709-lut-size65)
  identifies v1.0 for Osmo Pocket 4P. Downloading its cube and comparing SHA-256
  confirmed it is byte-for-byte identical to the supplied LUT:
  `fa6537da3235c281da6e361806d3e9ee93f5532ad95471878c5d6c05157caa9c`.
  All **274625** RGB entries are finite and within 0..1.

The test fixture records hashes of the source CTL, DCTL and LUT, independent
Python/NumPy reference values, and sparse neutral samples of the official LUT.
No complete vendor asset is embedded in the application.

## Transfer function

Let `E` be scene-linear exposure (18% grey is 0.18), `V` the native normalized
D-Log2 signal, and:

```
a  = 16.285770761945304
h  = 475 / (2^a - 1)
k1 = 0.059439938321493
b1 = 0.304985337243402
k2 = 2.960935245492250
b2 = 0.148314799066323
t  = 0.028961695254132
```

DJI's decoding function is:

```
E = h * (2^(a*V) - 1)                when V >= b1
E = 2^((V-b1)/k1 + log2(0.18))       when b2 <= V < b1
E = (V-b2)/k2 + t                    otherwise
```

The analytic inverse implemented for output is:

```
V = log2(E/h + 1) / a                when E >= 0.18
V = k1 * log2(E/0.18) + b1           when t <= E < 0.18
V = k2 * (E-t) + b2                  otherwise
```

LUTCalc's internal linear convention has middle grey at 0.2, so encoding
multiplies internal linear by 0.9 and decoding divides scene-linear by 0.9.
Both scalar and buffer methods preserve the linear negative extension.
The curve itself does not clamp; the existing LUT output clipping controls apply.

| Scene-linear E | Native signal V | Native 10-bit coordinate |
| --- | --- | --- |
| 0 | 0.062561094819158 | 64 |
| 0.028961695254132 | 0.148314799066323 | 151.726039 |
| 0.18 | 0.304985337243402 | 312 |
| 475 | 1 | 1023 |

## D-Gamut2

| Chromaticity | x | y |
| --- | --- | --- |
| Red | 0.7347 | 0.2653 |
| Green | 0.1600 | 0.8400 |
| Blue | 0.0900 | -0.0800 |
| White (D65) | 0.3127 | 0.3290 |

Column-vector D-Gamut2 to ACES AP0 matrix, using CAT02 D65 to D60:

```
 0.737038511535522   0.176660634320360   0.086300854144117
 0.000806604486082   1.070400242279923  -0.071206846766005
-0.000490685626043  -0.000923027602015   1.001413713228057
```

Negative primary coordinates and negative matrix coefficients are intentional.
D-Gamut2 is distinct from the existing D-Gamut and estimated D-GamutM.

## What the official Rec.709 LUT establishes

The LUT is a display rendering, not an invertible specification of D-Log2.
Its neutral output differs from a simple log decode and Rec.709 encoding:

| Equal RGB input V | Official equal RGB output |
| --- | --- |
| 0 | 0 |
| 0.0625 | 0.0294041 |
| 0.25 | 0.298741 |
| 0.3125 | 0.430045 |
| 0.5 | 0.802426 |
| 0.75 | 0.98645 |
| 1 | 1 |

For example, the IDT decodes V=1 to E=475, whereas the LUT maps it to display
white. At the IDT's black level (approximately 0.06256), the LUT is already above
zero. These samples support treating the LUT as a separate rendering; they do
not uniquely determine its tone mapping, range treatment or color processing.
Selecting Rec709 in LUTCalc therefore does **not** promise to reproduce DJI's
v1.0 look or the ACES RRT/ODT. Use the supplied cube itself for that specific look.

## Validation

Run `node --test tests/dlog2.test.js` (Node 18+; no npm installation).
Checks cover independent IDT reference values, joins and negative values,
all 1024 ten-bit codes in both ranges, scalar/buffer parity, neutral preservation,
full precision and rounded AP0 matrices, 1D generation, 33³ RGB round trips, full gamma/color/gamma cube serialization,
input/output registration, both worker loading paths and source/bundle parity.

The fallback color worker also required its existing Brent dependency, which
was missing from `colourspaceworkerscombined.js`; it is now included there.
The inline path already included Brent. Browser smoke checks cover selection
and the grey table (64 for black, 312 for 18% grey). These are mathematical and
application checks, not a sensor measurement or a Resolve footage comparison.

All nine tests passed. The bundled and unbundled browser entry points loaded
without script errors. The browser download event did not confirm a saved file;
the cube writer and its complete 33³ numeric payload were verified in the
engine test instead. Browser save-to-disk remains unverified.
