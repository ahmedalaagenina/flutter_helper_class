# Image Cleanup — smart signature/stamp preparation

Turns a raw signature or stamp picture (photo, scan, screenshot — PNG, JPEG,
WebP, GIF, BMP, TIFF) into an upload-ready, tightly cropped, **transparent
PNG**:

1. **Auto-detection** — finds the ink/content and seeds a crop rectangle
   around it (background color estimation + Otsu thresholding, robust to
   dust specks and JPEG noise).
2. **User adjustment** — the user fine-tunes the crop with draggable corner
   and edge handles, switches between **rectangle and circle/oval** crop
   shapes, or taps *Auto-detect* to reset to the detected box.
3. **Margin trim** — after processing, the output is re-trimmed to its
   content bounding box, so the result is *guaranteed* to have no extra
   margins (plus a small configurable safety padding).
4. **Background removal** — the (near-)uniform background is converted to
   transparency with a smooth alpha ramp; anti-aliased stroke edges are
   un-blended from the old background so there is no white halo. A
   checkerboard preview shows the transparency before the user confirms.

Everything runs **on-device** (no backend). Decode, downscale, resize and
PNG encode all go through the Flutter **engine codecs** (`dart:ui` —
`ImageDescriptor`, `decodeImageFromPixels`, `Image.toByteData`), which run in
native code off the UI thread on every platform, including web. Only the
per-pixel alpha math runs in Dart, on already-downscaled buffers, inside a
real isolate on mobile/desktop. Camera EXIF rotation is baked in and
oversized photos are capped **during decode** (the full-resolution bitmap
never materializes in Dart), so the flow stays smooth even with 12 MP
inputs. A pure-Dart decoder was deliberately avoided on the hot path:
decoding a camera photo in Dart allocates hundreds of MB, and the resulting
shared-heap GC pauses freeze the UI even when the work runs in an isolate.

**Layered decode:** files the engine codec rejects (TIFF, some BMP variants,
unusual JPEG encodings, mildly corrupt files) automatically fall back to the
lenient pure-Dart decoder (`package:image`), inside an isolate. The fallback
only ever runs after the engine path has failed, so normal photos never pay
its cost. Each fallback logs a `debugPrint` with the engine's error.

## Portability

The module is self-contained apart from localization. Its dependencies are:

- Flutter (Material + `dart:ui`)
- [`package:image`](https://pub.dev/packages/image) `^4.x` — **fallback
  decoder only**, never on the hot path
- this app's generated l10n (`S.of(context)`) — see
  [Localization](#localization) for the porting note

To reuse it in another app: **copy this folder**, add `image: ^4.0.0` to
that app's `pubspec.yaml`, and re-point the `S.of(context)` strings in
[image_cleanup_page.dart](presentation/pages/image_cleanup_page.dart) at that
app's localization (or hardcoded text). No routing package, DI container,
state management, or theme setup is required.

## Quick start

```dart
import 'features/image_cleanup/image_cleanup.dart';

Future<void> onPickedImage(Uint8List rawBytes) async {
  // Optional early rejection of non-image files (magic-byte check).
  if (!ImageCleanupHelper.isSupportedImage(rawBytes)) return;

  final CleanupResult? result = await ImageCleanupHelper.cleanImage(
    context,
    bytes: rawBytes,
  );
  if (result == null) return; // user cancelled

  upload(result.pngBytes); // tightly cropped, transparent PNG
}
```

`cleanImage` pushes a full-screen flow with a plain `Navigator` push, so it
works with go_router, auto_route, or vanilla navigation unchanged.

## API overview

| Entry point | What it does |
| --- | --- |
| `ImageCleanupHelper.cleanImage(context, bytes: …)` | One-liner: pushes the UI flow, resolves with `CleanupResult?` (null = cancelled). |
| `ImageCleanupHelper.isSupportedImage(bytes)` | Cheap magic-byte format check before decoding. |
| `ImageCleanupPage` | The flow as a widget, if you want to push/embed it yourself. Pops with `CleanupResult?`. |
| `ImageCleanupService.analyze(bytes)` | Headless: decode + normalize + detect content. Returns `CleanupAnalysis` (working PNG + suggested crop + background info). |
| `ImageCleanupService.process(analysis, crop: …)` | Headless: crop + oval mask + background removal + trim + resize + PNG encode. |
| `ImageCleanupService.normalizeToPng(bytes)` | Headless "use as-is" path: no cleanup, just decode → 8-bit RGBA PNG re-encode (EXIF baked, size capped). For uploads that bypass the cleanup UI but must stay PNG. |
| `AdjustableCropView` | The reusable crop editor widget (image + draggable handles, rectangle or oval), if you want to build a custom UI. |
| `CheckerboardBackground` | Transparency-checkerboard container for previews. |

The headless services make it possible to run the pipeline without any UI
(e.g. batch-clean images, or auto-clean silently and only show the editor on
demand).

### Results

`CleanupResult` carries:

- `pngBytes` — the final image, always PNG (transparency-capable)
- `width` / `height` — output dimensions
- `backgroundRemoved` — whether background transparency was produced

## Tuning — `CleanupOptions`

All knobs have sensible defaults; pass a custom `CleanupOptions` to
`cleanImage` / `analyze` / `process` to override.

| Option | Default | Meaning |
| --- | --- | --- |
| `removeBackground` | `true` | Convert the background to transparency (the user can also toggle this in the UI). |
| `cropShape` | `rectangle` | Initial crop shape; `oval` keeps only the ellipse inscribed in the crop rect (round stamps). The user can switch shapes in the UI. |
| `sensitivity` | `0.5` | 0..1. Higher keeps faint pen strokes; lower removes more background/shadows. |
| `inkStyle` | `original` | `original` keeps the real ink colors (edge-unblended); `solid` recolors all ink to `solidInkColor` for a crisp uniform look. |
| `solidInkColor` | near-black | Ink color used with `InkStyle.solid`. |
| `outputMaxDimension` | `1200` | Longest side of the output; `0` keeps full working resolution. |
| `outputPaddingPx` | `6` | Transparent safety margin around the trimmed content. |
| `detectionPaddingFraction` | `0.04` | Padding added around the auto-detected box. |
| `trimTransparentResult` | `true` | Re-trim the final image to its content so no margins survive. |
| `analysisMaxDimension` | `640` | Detection-pass downscale cap (speed knob). |

## Localization

The page reads its text from this app's generated localizations
(`S.of(context)`), backed by these keys in `lib/l10n/intl_en.arb` /
`intl_ar.arb`:

`imageCleanupAdjustTitle`, `imageCleanupPreviewTitle`,
`imageCleanupAnalyzing`, `imageCleanupProcessing`, `imageCleanupCropHint`,
`imageCleanupRemoveBackground`, `imageCleanupShapeRectangle`,
`imageCleanupShapeCircle`, `imageCleanupAutoDetect`, `imageCleanupContinue`,
`imageCleanupBack`, `imageCleanupUseImage`, `imageCleanupTransparencyHint`,
`imageCleanupCouldNotReadImage`, `imageCleanupClose` — plus
`unsupportedImageFormat` used at the pick call sites.

**When porting to another app**, these `S.of(context)` references in
`image_cleanup_page.dart` are the only app-specific code — swap them for the
target app's localization or plain strings.

## How it works (pipeline details)

```
raw bytes
   │  analyze()
   ├─ ENGINE decode (EXIF baked) with target size ≤1600 px — the full-res
   │  bitmap never exists in Dart
   ├─ toByteData(rawStraightRgba) → working RGBA buffer + ui.Image for display
   ├─ detection on a ≤640 px sample grid of that buffer (inline, ~tens of ms):
   │    background color = median of the border-ring pixels
   │    distance map     = per-pixel RGB distance from the background
   │                       (or the alpha channel, if the source already has
   │                        real transparency — then removal is skipped)
   │    ink threshold    = Otsu's method over the distance histogram,
   │                       floored to ignore JPEG noise
   └─ suggested crop     = ink bounding box, ignoring up to 0.3% stray
                           specks per side, padded by 4%

user adjusts crop (AdjustableCropView, RawImage — no re-decode) — rect or oval

   │  process()
   ├─ buffer math in an isolate (compute) on the cropped region only:
   │    crop rows → oval mask (feathered) → background removal (smoothstep
   │    alpha ramp around the Otsu threshold, edges un-blended from the old
   │    background so no white halo) → trim to content → premultiply
   ├─ ENGINE decodeImageFromPixels with target size ≤ outputMaxDimension
   ├─ padding/background canvas pass (engine raster)
   └─ ENGINE toByteData(png) → final PNG
```

Design choices worth knowing:

- **Everything after `analyze` uses the same working pixels**, so what the
  user sees in the crop editor is exactly what gets processed (no
  EXIF-rotation coordinate mismatches), and the editor displays the decoded
  `ui.Image` directly via `RawImage` — zero extra encode/decode round trips.
- **The border-ring median** is a reliable background estimate because
  signatures/stamps essentially never touch all four edges of the picture.
- **Loading is always visible:** analysis starts only after the page's first
  frame (plus a short delay for the push transition), and processing yields
  a frame before the heavy work, so the spinner is painted before the CPU
  gets busy.
- **Web:** Dart isolates don't exist on web (`compute` runs inline), so the
  buffer math — and the pure-Dart fallback decode for engine-rejected files —
  briefly block the UI thread there. This is a deliberate simplicity
  trade-off: the busy states show a "this might take a moment, please don't
  close the page" notice instead of carrying a second, chunked copy of the
  pipeline. The engine codec work (decode/resize/PNG encode) is native even
  on web.
- **Limitations:** the background must be *roughly uniform* (paper, solid
  color). Busy backgrounds (wood grain, lined paper) won't key out cleanly —
  the user still gets the crop step, and the *Remove background* toggle lets
  them keep the original pixels. For ML-grade segmentation of arbitrary
  backgrounds you'd need a server-side model (e.g. rembg); this module was
  deliberately kept dependency-free and offline.

## File map

```
image_cleanup/
├── image_cleanup.dart                 # barrel — import this
├── image_cleanup_picker.dart          # app-integration glue: pick → validate → clean
│                                      # (rewrite against the target app when porting)
├── README.md
├── domain/
│   ├── cleanup_options.dart           # tuning knobs (CleanupOptions, CropShape, InkStyle)
│   └── cleanup_result.dart            # CleanupResult, InkAnalysis
├── services/
│   ├── ink_detection_service.dart     # bg estimation, Otsu, ink bounding box
│   ├── background_removal_service.dart# alpha keying, edge un-blending, oval mask, trim bounds
│   └── image_cleanup_service.dart     # isolate-based analyze/process facade
├── helpers/
│   └── image_cleanup_helper.dart      # cleanImage() one-liner, format check
└── presentation/
    ├── pages/image_cleanup_page.dart  # the 2-step flow (adjust → preview)
    └── widgets/
        ├── adjustable_crop_view.dart  # draggable crop editor (rect/oval)
        └── checkerboard_background.dart
```

## Where it's wired up in this app

All three upload surfaces call the single shared entry point
`ImageCleanupPicker.pickAndClean(context)`, so accepted formats and error
handling cannot drift. After picking, the user chooses via an action sheet:

- **Edit & Cleanup** — the interactive flow described above.
- **Use Original** — bypasses the UI entirely; the image is silently
  re-encoded via `ImageCleanupService.normalizeToPng` so the output is
  still a guaranteed 8-bit RGBA PNG (pixels untouched apart from EXIF
  baking and the 1600 px size cap).

