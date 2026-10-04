# Colour Space / Transfer Function Coverage Survey

> 2026-09-23 补充：本文件保留为历史调查。当前运行计数、别名更正、新设备与资料状态请见[中文补充调查](colour-research-2026-09-23.md)及[纯算法审计](algorithm-only-audit.md)。

Verified 2026-09-22. A static audit of every named colour space (gamut /
primaries) and transfer function (gamma) registered in LUTCalc, plus the gaps
against the mainstream camera and broadcast/OTT landscape. This is a survey
only; nothing in the engine was changed.

Scope: the JS engine and UI registration tables. LUT *formats* (`.cube`,
`.3dl`, `.vlt`, ...) are out of scope, as are the ASC/PSST CDL and highlight
tweaks which operate on already-selected curves.

## Where the registries live

| What | Function | Location |
| --- | --- | --- |
| Gamut matrices / primaries | `LUTColourSpace.prototype.xyzMatrices` | `js/colourspace.js:836` (primaries at `:840-1179`) |
| Gamut in/out registration | `LUTColourSpace.prototype.loadColourSpaces` | `js/colourspace.js:140-479` |
| Gamut maker categories | `LUTColourSpace.prototype.subIdx` / `subNames` | `js/colourspace.js:115-139`, `:141` |
| Transfer functions | `LUTGamma.prototype.gammaList` | `js/gamma.js:110-1590` |
| TF maker categories | `LUTGamma.prototype.subIdx` / `subNames` | `js/gamma.js:88-109`, `:111` |
| TF implementation classes | `LUTGamma*` | `js/gamma.js:2412-4170` |
| Camera presets | `this.cameras.push(...)` | `js/lutcamerabox.js:161+` |
| Custom primaries / white point UI | `TWKCS` | `js/twk-cs.js:37`, `:587-610` |

Each TF registers four parallel arrays after the constructor push
(`js/gamma.js:131-1590`): `gammaSub` (maker + category filter indices),
`gts` (default matching gamut name, or `'*'` for any), `gammaDat`
(data-range preference), `gammaExt` (extension/LUTAnalyst eligibility).

Bundles that mirror these tables and must be kept in step by hand
(`docs/dlog2.md` records a case where they had drifted): `js/lutcalccombined.js`
(loaded by `index.html`), `js/gammaworkerscombined.js` (via
`js/gammaworker.js:3`), `js/colourspaceworkerscombined.js` (via
`js/colourspaceworker.js:3`). `indexunminified.html` loads the loose
`js/gamma.js` / `js/colourspace.js` instead.

## Supported colour spaces (43 matrix entries + specials)

`xyzMatrices` primaries, in registration order (`js/colourspace.js:840-1179`):

**Vendor / camera gamuts**
Sony S-Gamut3.cine, Sony S-Gamut3.cine (Venice), Sony S-Gamut3,
Sony S-Gamut3 (Venice), Sony S-Gamut, ARRI Wide Gamut 4, Alexa Wide Gamut,
Canon Cinema Gamut, Panasonic V-Gamut, Fujifilm F-Log Gamut,
Blackmagic Wide Gamut, DaVinci Wide Gamut, Blackmagic 4k Film,
Blackmagic 4.6k Film, Blackmagic Pocket 6k Film, REDWideGamutRGB,
DRAGONColor, DRAGONColor2, REDColor, REDColor2, REDColor3, REDColor4,
Bolex Wide Gamut, DJI D-Gamut, DJI D-Gamut2, DJI D-GamutM, Protune Native.

**Standards and display gamuts**
Rec709, Rec2020, Rec2100, sRGB, ACES AP0, ACEScg AP1, XYZ, P3 - DCI,
P3 - D60, P3 - D65, Canon DCI-P3+, Adobe RGB, Adobe Wide Gamut RGB,
ProPhoto RGB.

**Non-matrix entries** (added in `loadColourSpaces` and the csOut tail)
Canon CP IDT (Daylight) / (Tungsten) as `CSCanonIDT` LUTs
(`js/colourspace.js:238-241`, `:405-419`); CIELAB D65 / CIELAB D50 as
`CSLabSpace` (`js/colourspace.js:250-253`); output-only Luma B&W, Passthrough
and LA (`js/colourspace.js` csOut tail); Custom In / Custom Out editable
primaries (`js/colourspace.js:255`, `:479`).

## Supported transfer functions (118 registrations, ~116 unique names)

Grouped by the `subNames` filter categories (`js/gamma.js:111`).

**Log / camera log**
S-Log3, S-Log2, S-Log, LOGCalc Scaler, LogC4, LogC (Sup 3.x & 4.x),
LogC (Sup 2.x), Canon C-Log2, Canon C-Log3, C-Log, Apple Log, Cineon,
Panasonic V-Log, Fujifilm F-Log2, Fujifilm F-Log, REDLogFilm, RED Log3G10,
BMDFilm Gen5, DaVinci Intermediate, BMD Pocket Film, BMD Film, BMD Film4k,
BMD Film4.6k (registered twice, `js/gamma.js:273` and `:280`), Bolex Log,
Panalog, Protune, DJI X5/X7/X9 DLog, DJI D-Log2, DJI DLog-M, DJI X3 DLog,
DJI Mini 2, ACEScc, ACESproxy10, ACESproxy12, Nikon N-Log.

**In-camera look / display render**
Amira709, Alexa-X-2, s709, LC709A, LC709, Sony Cine+709, Varicam V709,
REDGamma, REDGamma2, REDGamma3, REDGamma4, Rec709 (800%), EOS Standard,
EOS Standard (Legal), Canon Normal 1-4, Canon WideDR (registered twice,
`js/gamma.js:1371` and `:1385`), Nikon Standard, Nikon Neutral, Nikon Vivid,
Nikon Monochrome, Nikon Portrait, Nikon Landscape.

**Sony HyperGamma / Cinegamma / STD**
HG3250G36 (HG1), HG4600G30 (HG2), HG3259G40 (HG3), HG4609G33 (HG4),
HG8000G36 (HG5), HG8000G30 (HG6), HG8009G40 (HG7), HG8009G33 (HG8),
Cinegamma1-4, Sony STD1, Sony STD2 - x4.5, Sony STD3 - x3.5,
Sony STD4 - SMPTE240M, Sony STD5 - Rec709, Sony STD6 - x5.

**HDR display**
Rec2100 PQ (PQ OOTF), Rec2100 PQ (HLG OOTF), Rec2100 HLG, PQ (EOTF Only),
ITU Proposal (400%), ITU Proposal (800%), BBC WHP283 (400%),
BBC WHP283 (800%), plus the OOTF pairs Display PQ / HLG OOTF in nits and
Normalised form and Scene Linear (nits) (`js/gamma.js:1030-1062`).

**Display / linear / power**
Rec709, Rec2020 12-bit, sRGB, DCI (γ2.60), Scene Linear IRE,
Scene Reflectance, CIE L*, BBC 0.4, BBC 0.5, BBC 0.6, ProPhoto / ROMM,
γ1.5 through γ2.6, Linear / γ (custom, idx 9999), LA, Null.

## Coverage gaps - colour spaces

| Priority | Missing gamut | Paired TF | Notes |
| --- | --- | --- | --- |
| High | **L-Gamut** (Leica) | L-Log | Leica SL2 / SL2-S / SL3 / SL3-S, M11 with L-Log |
| High | **OM-Gamut** (OM System) | OM-Log400 | OM-1 / OM-1 II / OM-5 |
| High | **Z-Gamut** (Z CAM) | Z-Log2 | Z CAM E2 / F6 / F8 |
| High | **KineColor2 / KineColor3** (Kinefinity) | KineLOG3 | MAVO Edge / TERRA |
| Medium | **SMPTE 240M / Rec.240M** primaries | — | Distinct from Rec709; legacy broadcast |
| Medium | **scRGB** | — | Rec709 primaries, linear wide encoding |
| Low | Display P3 | — | Alias of the existing P3 - D65 |
| Low | ARRI Wide Gamut 3 (AWG3) | — | Alias of the existing Alexa Wide Gamut |
| Low | Rec.601 / EBU 3213 / SMPTE 170M / FCC | — | Primaries identical to Rec709; naming only |

`P3 - DCI / D60 / D65` already covers Display P3 and DCI-P3.
`Canon DCI-P3+` covers Canon's P3 variant. Canon's non-plus DCI-P3 is
unlisted but equals `P3 - DCI` for this purpose.

## Coverage gaps - transfer functions

| Priority | Missing TF | Notes |
| --- | --- | --- |
| **Highest** | **ACEScct** | ACES 1.x grading curve. Only `ACEScc` and `ACESproxy10/12` exist (`js/gamma.js:383-396`). Resolve and ACES pipelines expect it |
| High | **Blackmagic Video** / **Blackmagic Extended Video** | BMD in-camera non-log curves. Only the BMD Film family is present |
| High | **DJI D-Cinelike** | DJI in-camera non-log. Only the D-Log family is present |
| High | **Panasonic Cinelike D** / **Cinelike V** | GH4 / GH5 / GH6 / S1 / S5 in-camera non-log. Only V-Log is present |
| High | **Leica L-Log** | — |
| High | **OM-Log400** (OM-Log) | — |
| High | **Z-Log2** | — |
| High | **KineLOG3** | — |
| Medium | **Fujifilm F-Log2 C** | Post-2024 Fuji variant alongside F-Log2 |
| Medium | **Rec.2020 10-bit** | Native Swift `rec2020.bt2020-10bit.v1` is now registered separately from the historical `Rec2020 12-bit`; see `docs/native-validation/2026-10-03-rec2020-tenbit.md` |
| Medium | **BT.1886** (Rec.1886) | Reference-display EOTF with Lb. Not the same as the bare γ2.4 entry |
| Medium | **Rec.709-A** | Apple / Final Cut Pro ecosystem convention |
| Medium | GoPro **GP-Log** / GoPro **Flat**, Nikon **Flat**, Panasonic **Natural** / **Premium** / **Like709** | In-camera non-log families |
| Low | SMPTE 240M as a standalone TF | Approximated today by the `Sony STD4 - SMPTE240M` look LUT |
| Low | Insta360 **I-Log**, Samsung **Log** | Action / phone capture |
| Low | Oklab / Oklch | Grading space, not a capture or display TF |
| Low | γ2.8 | Legacy print / CRT reference |

Existing near-misses worth not re-adding under new names:
`Rec709` (γ 0.45) and `Rec2020 12-bit` share a shape; `Sony STD4 - SMPTE240M`
already encodes the 240M curve; `DCI` is γ2.60; `CIE L*` covers the L\*
transfer; the `γ1.5`-`γ2.6` ladder covers pure power curves except 2.8.

## Camera preset gaps

`js/lutcamerabox.js` registers 67 presets across 11 makes only: Sony (23),
DJI (13), Blackmagic (8), Panasonic (6), Canon (5), Nikon (4), ARRI (2),
Fujifilm (2), RED (1), Apple (1), GoPro (1).

No presets at all for **Leica, OM System, Z CAM, Kinefinity, Insta360,
Samsung**. Preset fields are `make, model, iso, type, defgamma, defgamut,
bclip, wclip` (`js/lutcamerabox.js:161+`). `type` selects the stop/EI
behaviour; `defgamma` / `defgamut` must name entries that already exist in
the two registries, so a preset cannot land before its TF and gamut.

## Mitigation already in the app

- Gamut gaps are partly user-patchable: `TWKCS` (`js/twk-cs.js:37`) edits
  custom primaries and white point with a CCT / illuminant table
  (`js/twk-cs.js:587-610`), and Custom In / Custom Out are registered gamuts.
  A missing gamut can therefore be entered by hand, at the cost of accuracy
  and convenience.
- TF gaps are not patchable. Each curve needs a `LUTGamma*` class
  (`js/gamma.js:2412-4170` has reusable skeletons: `LUTGammaLog` for the
  common 9-parameter log form, `LUTGammaGam` / `LUTGammaBBCGam` for piecewise
  power, `LUTGammaPQ` / `LUTGammaHLG` for HDR, `LUTGammaIOLUT` /
  `LUTGammaLUTSL3` / `LUTGammaLUTSimple` for table-driven looks).
- `LUTGammaLog` (`js/gamma.js:2479`) covers any curve of the
  `[c0..c8]` piecewise-log family used by S-Log, C-Log, V-Log, F-Log,
  BMD Film, Panalog and DJI D-Log, so several medium-priority log entries
  (L-Log, OM-Log400, Z-Log2, F-Log2 C) are data-only additions once the
  constants are confirmed from the vendor white papers.

## Suggested implementation order

1. **ACEScct** - largest gap in an otherwise complete ACES story, and a
   small `LUTGammaLog`-style constant set from the ACES spec.
2. **DJI D-Cinelike**, **Panasonic Cinelike D / V** - mainstream in-camera
   non-log for widely owned cameras already half covered by the preset list.
3. **Blackmagic Video / Extended Video** - completes the BMD family that is
   already well represented in presets.
4. **L-Log + L-Gamut**, **OM-Log400 + OM-Gamut**, **Z-Log2 + Z-Gamut**,
   **KineLOG3 + KineColor2/3** - each pair opens a whole new maker; also add
   the matching `subIdx` / `subNames` category and camera presets in the same
   change.
5. **BT.1886**, **Rec.709-A**, **F-Log2 C**. Rec.2020 10-bit now has a native Swift analytic subset; full display/workflow coverage remains separate.

Every item must be added to `js/gamma.js` and/or `js/colourspace.js` *and*
mirrored into `js/lutcalccombined.js`, `js/gammaworkerscombined.js`,
`js/colourspaceworkerscombined.js`, then re-checked with the Node test
convention used by `tests/dlog2.test.js` (`node --test tests/*.test.js`,
Node 18+, no npm install).

## Verification method

Registry names were extracted from the source tables (constructor first
arguments in `gammaList`, `.name =` assignments and `toSys` / `fromSys`
arguments in `xyzMatrices` / `loadColourSpaces`), then cross-checked against
`js/lutcamerabox.js` defaults and the `subIdx` category switches. Absence of
each gap item was confirmed by a repo-wide search for its name and common
aliases. Counts are registration counts, not unique labels: BMD Film4.6k and
Canon WideDR are each registered twice.
