# Device Security

A drop-in device integrity gate for Flutter apps: **real Android phones and real
iPhones/iPads only.**

It refuses to run on

- **Windows, macOS and Linux** builds,
- **Windows Subsystem for Android**,
- **Android app players and emulators** — BlueStacks, LDPlayer, Nox, MEmu,
  Genymotion, MuMu, KoPlayer, Windroy, Waydroid, Anbox, the Android Studio /
  AOSP emulator, Android-x86 / PrimeOS / Phoenix OS in a VM,
- the **iOS Simulator** and "Designed for iPad" apps on Apple Silicon macOS,
- **rooted / jailbroken** devices and non-retail (`test-keys`, `userdebug`,
  `eng`) builds,
- optionally, **sideloaded or re-signed** copies of the app,
- optionally, Android devices with **developer options** or **USB debugging** on.

This folder is **self-contained and app-agnostic**. It imports nothing from the
host app — copy the whole directory into another project, add the three
dependencies below, and wire it up.

---

## Contents

| File | What it is |
| --- | --- |
| `device_security.dart` | Barrel export. Import just this. |
| `device_integrity.dart` | The detection engine. Static, cached, app-agnostic. |
| `device_integrity_config.dart` | Host policy: what to block, how confident to be, reporting hooks. |
| `device_integrity_result.dart` | `DeviceBlockReason` + `DeviceIntegrityResult`. |
| `device_signal.dart` | `DeviceSignal` + `SignalWeight` — the scoring model. |
| `device_probe.dart` | `DeviceProbe`: the one place plugins and `dart:io` are touched. |
| `device_fingerprints.dart` | The detection tables (const data, no logic). |
| `device_gate.dart` | `DeviceGate` — the widget that actually blocks the UI. |
| `device_blocked_screen.dart` | Default block UI + `DeviceGateStrings` / `DeviceGateTheme`. |
| `test/` | 50 tests. Move them to your app's `test/` folder. |
| `WALKTHROUGH.md` | كيف يعمل الكود من الداخل، خطوة بخطوة (بالعربي). |

Dependencies: `device_info_plus`, `safe_device`, `package_info_plus`.

---

## Setup

### 1. Configure and evaluate in `main()`

```dart
import 'package:<app>/config/security/device_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DeviceIntegrity.configure(
    DeviceIntegrityConfig(
      bypass: () => Prefs.isStoreReviewer,          // see "Store review" below
      onEvaluated: (r) => Analytics.log('device_check', {'ref': r.reference}),
      onBlocked: (r) => Crashlytics.instance.log('device_blocked ${r.reference}'),
      onProbeError: (probe, e, s) =>
          Crashlytics.instance.recordError(e, s, reason: 'probe:$probe'),
    ),
  );

  // Before runApp, so the first frame already has a verdict.
  await DeviceIntegrity.evaluate();

  runApp(const MyApp());
}
```

### 2. Mount the gate in `MaterialApp.builder`

```dart
MaterialApp(
  builder: (context, child) => DeviceGate(child: child!),
  home: const SplashPage(),
)
```

> **Use `builder`, not `home`.** Above the Navigator the gate also covers routes
> opened from notifications and deep links, and it survives auth flows that end
> with `Navigator.pushAndRemoveUntil(..., (route) => false)` — that call tears
> down the `home` route, so a gate placed there is navigated straight past.

If you already use `builder` for something else, compose them — outermost wins:

```dart
final easyLoading = EasyLoading.init();   // build once, not per frame
...
builder: (context, child) => DeviceGate(child: easyLoading(context, child)),
```

That is all. Blocked devices now see the block screen instead of the app.

---

## How a verdict is reached

Detection produces **signals**, and each signal carries a **weight**. A category
blocks only once its surviving signals add up to `blockThreshold` (100 by
default).

| Weight | Points | Meaning |
| --- | --- | --- |
| `conclusive` | 100 | Cannot occur on retail hardware. Blocks alone. |
| `strong` | 60 | Reliable, but has a plausible false-positive path. Two of these block. |
| `weak` | 30 | Seen on real devices too. Corroboration only. |

This is the difference between a gate that works and a gate that costs you
customers. `Build.BOOTLOADER == "unknown"` is reported by a great many modern
retail phones — as a `conclusive` signal it would lock them all out; as `weak`
it is just context. Conversely `safe_device` answers `false` when its *own*
platform channel fails, so `safe_device:emulator` is `strong`, never enough on
its own — one broken build must not block every user.

Worked examples:

```
Galaxy S23        bootloader:unknown(30)                                 =  30  → allowed
Intel Zenfone 2   hardware:intel(30) bootloader:unknown(30) abi:x86(30)  =  90  → allowed
Real emulator     safe_device:emulator(60) build:not-physical(60)        = 120  → BLOCKED
BlueStacks        file:bluestacks(100)                                   = 100  → BLOCKED
```

---

## Login first, decide after

The common requirement: **let anyone reach the login screen, then use whatever
the sign-in response says to decide who may continue.** Store reviewers run the
app on emulators and are only recognisable after they sign in, so the login
screen has to stay reachable on a device that is otherwise blocked.

Two knobs do this, and neither of them re-probes the device:

```dart
// main() — the exemption, re-read on every gate rebuild
DeviceIntegrity.configure(DeviceIntegrityConfig(
  bypass: () => session.user?.isReviewer ?? false,
));
await DeviceIntegrity.evaluate();

// MaterialApp.builder — the hole that keeps sign-in reachable
DeviceGate(
  allowWhen: () => !session.hasAccount,   // fresh install → login stays open
  refreshOn: session,                     // close/open the instant login lands
  child: child!,
)
```

What happens, in order:

| # | Event | `verdict` | `allowWhen` | Screen |
| --- | --- | --- | --- | --- |
| 1 | `main()` on BlueStacks | `emulator[100]` | — | — |
| 2 | first frame, no account | `emulator[100]` | `true` | **login** |
| 3 | ordinary user signs in | `emulator[100]` | `false` | **blocked** |
| 3′ | reviewer signs in | `allowed` | `false` | **app** |

Step 3 runs **no platform checks at all**. The device did not change when
somebody logged in — the *policy* did. `DeviceIntegrity.verdict` folds the
bypass in on every read, and `refreshOn` just triggers the rebuild that reads
it. Call `evaluate(force: true)` only if you want a fresh telemetry event
against the now-known user id.

Two details that matter:

- **`hasAccount` must be sticky.** `allowWhen: () => !session.isSignedIn` looks
  equivalent and is not: it reopens the gate for anyone who taps "log out",
  which turns the login hole into a permanent bypass. Use a flag that means
  "somebody has signed in on this install at least once" and never clear it.
- **`bypass` is the module's weakest link.** A `SharedPreferences` boolean is
  trivially flipped on exactly the rooted devices you are blocking. Treat it as
  UX, and let the server refuse the actual content — see "Going further".

`kDebugMode` is exempt by default (`allowDebugBuilds`), so you can still develop
against an emulator. Release and profile builds are **not** exempt. Note that an
exempt build is still *checked* — only the block and the reporting are
suppressed, so `lastResult` always describes the hardware.

### `lastResult` vs `verdict`

| | Answers | Changes when |
| --- | --- | --- |
| `DeviceIntegrity.lastResult` | "what is this **device**?" | you call `evaluate()` |
| `DeviceIntegrity.verdict` | "what happens to **this user, now**?" | every read |

Read `verdict` when deciding whether to show something. Read `lastResult` when
reporting or when sending the device state to your server.

---

## Policy options

```dart
DeviceIntegrityConfig(
  blockEmulators: true,            // emulators, VMs, app players
  blockCompromisedDevices: true,   // root / jailbreak / test-keys builds
  blockTamperedInstalls: false,    // sideloaded / re-signed app — see below
  blockDeveloperMode: false,       // Android developer options
  blockUsbDebugging: false,        // ignored unless blockDeveloperMode is true
  allowDebugBuilds: true,          // skip everything in kDebugMode
  blockThreshold: 100,             // points needed to block
  probeTimeout: Duration(seconds: 5),
  evaluationTimeout: Duration(seconds: 10),
  probe: null,                     // swap in a fake, or your own attestation
  bypass: () => false,
  ignoredSignals: {},              // retire a false positive, see below
  ignoreSignal: null,              // …or an arbitrary predicate
  signalWeights: {},               // re-weight without editing the module
  extraEmulatorArtifacts: {},      // extra file fingerprints
  extraRootArtifacts: {},
  extraJailbreakArtifacts: {},
  expectedSignatures: {},          // pinned Android signing certificate SHAs
  allowedInstallerStores: DeviceFingerprints.trustedInstallerStores,
  onEvaluated: (result) {},        // every changed verdict, pass or block
  onBlocked: (result) {},          // changed blocking verdicts only
  onProbeError: (probe, e, s) {},  // a check that could not answer
)
```

**`blockDeveloperMode` is off by default.** It is the strictest flag and it
fires on a large slice of ordinary users — anyone who followed a YouTube
tutorial or had their phone serviced. Measure with `onEvaluated` before turning
it on.

**`blockTamperedInstalls` is off by default.** It asks a different question from
the rest of the module: not "is this device genuine" but "is this *app*
genuine". Pin your certificate and it becomes the sharpest anti-piracy check
here, because a cracked build must be re-signed:

```dart
blockTamperedInstalls: true,
expectedSignatures: {'a1b2c3…'},   // your release signing cert SHA
```

Without `expectedSignatures` only the installer store is checked, which is
`strong` and will not block on its own — deliberately, because iOS frequently
reports no installer even for a legitimate App Store install. Promote it if your
app is Android-only:

```dart
signalWeights: {'installer:': SignalWeight.conclusive},
```

---

## Reading a verdict

```dart
final result = await DeviceIntegrity.evaluate();
result.isAllowed;   // bool
result.reason;      // DeviceBlockReason.emulator
result.score;       // 130
result.signals;     // ['build:bluestacks', 'abi:x86_64', 'file:bluestacks']
result.evidence;    // the same, with weights attached
result.reference;   // 'emulator[130]: build:bluestacks, abi:x86_64, file:bluestacks'
```

`reference` is printed at the bottom of the default block screen and is what you
should ask a user to quote in a support ticket — it tells you exactly which
checks fired and how close to the threshold they got. It is hidden in release
builds by default (`DeviceGate.showReference`) so it does not tell an attacker
which check caught them.

An **allowed** result carries evidence too: a device that scored 60 against a
threshold of 100 is precisely what you want in telemetry before tightening
anything.

Every signal is `category:value`:

| Prefix | Meaning |
| --- | --- |
| `build:` | A name matched somewhere in `android.os.Build` |
| `hardware:` `board:` `product:` `manufacturer:` `bootloader:` `fingerprint:` | That specific `Build` field |
| `abi:` | The device exposes no ARM ABI at all — x86-only |
| `feature:` | An app-player-specific `PackageManager` system feature |
| `file:` | A file that only exists inside that emulator / root / jailbreak image |
| `wsa:` | Windows Subsystem for Android |
| `ios:` | Simulator, machine identifier, or iOS-app-on-macOS |
| `installer:` `signature:` | Where the app came from, and how it was signed |
| `safe_device:` | The native `safe_device` check |
| `platform:` | Web or a desktop OS |
| `developer-options` `usb-debugging` | Android developer settings |

---

## Tuning detection

### A real device is being blocked (false positive)

1. Get the `reference` string from the user or from `onEvaluated` telemetry.
2. Ship a hotfix. Either retire the signal outright:

   ```dart
   ignoredSignals: {'hardware:intel'},   // one signal
   ignoredSignals: {'abi:'},             // a whole category — note the colon
   ignoreSignal: (id) => id.startsWith('ios:machine-'),
   ```

   …or just demote it, which keeps it useful as corroboration:

   ```dart
   signalWeights: {'safe_device:emulator': SignalWeight.weak},
   ```
3. If it turns out to be a systematic mistake, fix `device_fingerprints.dart`
   properly and add a test for the device that was wrongly blocked.

### A new emulator is getting through

Add its fingerprints to `device_fingerprints.dart` (or, without touching the
module, via `extraEmulatorArtifacts`):

- `emulatorNames` — matched as a **substring** of any `Build` field, weighted
  `conclusive`. Only put strings here that cannot appear on retail hardware.
- `emulatorExactValues` — matched **exactly** against `hardware` / `board` /
  `product`, also `conclusive`.
- `ambiguousExactValues` — same matching, but `weak`. This is where `intel`,
  `x86` and `cancro` live, because real phones report them too.
- `emulatorArtifacts` — absolute paths that only exist in that image.

---

## Behaviour notes

- **Cached.** `evaluate()` runs the platform checks once; later calls return the
  cached verdict. Concurrent callers share one evaluation, so `main()` and the
  gate's own start-up check never probe twice.
- **Two depths.** `evaluate(force: true)` re-runs the cheap checks;
  `evaluate(deep: true)` also re-scans the ~50 filesystem fingerprints. The
  gate's resume re-check is shallow (those paths cannot appear under a running
  app, and 50 blocking `stat` calls per resume is real jank); the block screen's
  "check again" button is deep.
- **Re-checks on resume** (`recheckOnResume`, on by default), catching someone
  who enables developer options while the app is in the background.
- **Fails open per probe.** A probe that throws or never answers contributes
  nothing and is reported through `onProbeError` — it does **not** discard the
  signals its siblings already found. This distinction is the whole point:
  wrapping the evaluation in a single `try` means anyone who can make one
  platform channel fail can open the gate completely.
- **Bounded.** Every probe is capped by `probeTimeout` and the whole evaluation
  by `evaluationTimeout`, so a hung channel cannot stop `main()` from reaching
  `runApp`.
- **Reports changes, not sessions.** `onBlocked` / `onEvaluated` fire only when
  the verdict actually changes, so resume re-checks do not turn your telemetry
  into a session counter.
- **No content flash.** Until the first verdict lands the gate paints
  `pendingBuilder` (a blank surface by default), never the app.
- **Not compiled for web.** `device_probe.dart` imports `dart:io`, so a web
  build fails at compile time rather than at runtime. The `kIsWeb` branch in the
  engine only matters if you supply your own `DeviceProbe`.
- **Not a substitute for server-side checks.** Everything here runs in the app
  process, so a determined attacker with a patched binary can defeat it. It
  raises the cost of casual piracy — running your lessons in BlueStacks on a PC
  — it does not make the app tamper-proof. See "Going further" below.

---

## Custom block screen

```dart
DeviceGate(
  blockedBuilder: (context, result, retry) => MyBrandedBlockPage(
    reason: result.reason,
    onRetry: retry,
  ),
  child: child!,
)
```

Or keep the default screen and just restyle it:

```dart
DeviceGate(
  strings: DeviceGateStrings(title: l10n.unsupportedDevice, /* … */),
  theme: DeviceGateTheme(background: AppColors.white, accent: AppColors.blue),
  child: child!,
)
```

`DeviceGateStrings` defaults to English, so the module works before you have
translations.

---

## Testing

The engine never touches a plugin directly — everything goes through
`DeviceProbe`. That makes the detection tables testable against synthetic
devices:

```dart
final result = await evaluateWith(configFor(FakeDeviceProbe(
  android: galaxyS23,
  existingPaths: {'/data/bluestacks.prop'},
)));
expect(result.reason, DeviceBlockReason.emulator);
```

`test/` ships with 43 tests covering the scoring model, the false positives that
matter (`bootloader:unknown`, Intel x86 phones, a `safe_device` plugin that
failed to register), the fail-open policy, iOS, tampering and the gate widget
itself. Copy the folder into your app's `test/` directory and fix the import.

**Note:** `flutter test` runs in debug mode, so any config used in a test must
set `allowDebugBuilds: false` or every check is bypassed.

---

## Going further

Two things this module deliberately does not do:

**Gate the network layer.** `DeviceGate` protects the UI; background isolates,
notification handlers and API calls keep running on a blocked device. Add an
interceptor:

```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    final verdict = DeviceIntegrity.lastResult;
    if (verdict != null && !verdict.isAllowed) {
      return handler.reject(DioException(requestOptions: options));
    }
    options.headers['X-Device-Integrity'] = verdict?.reference ?? 'pending';
    handler.next(options);
  },
));
```

**Attest server-side.** Everything above raises the cost of casual piracy. The
only wall a patched binary cannot walk through is a verdict signed by the
platform:

- **Play Integrity API** (Android) — Google signs the verdict, your server
  verifies it.
- **App Attest / DeviceCheck** (iOS).

Refuse to serve the actual content without a valid attestation, and this module
becomes what it should be: the UX layer that tells people *why* the app will not
run, not the last line of defence.

---

## How this app wires it

`lib/config/app_security.dart` holds everything specific to this project —
SharedPreferences tester flags, brand colours, `S.of(context)` strings, the auth
provider — and exposes two things:

- `AppSecurity.configure()`, called from `main.dart` before `runApp`;
- `AppDeviceGate`, mounted from `MaterialApp.builder` in `start/my_app.dart`.

`MainProvider.isRealDevice` mirrors the verdict so older widgets can keep reading
a plain bool; it is defence in depth, not the gate.

Localization keys used: `unsupportedDevice`,
`thisAppRunsOnlyOnGenuineAndroidPhonesAndIPhones`,
`emulatorOrVirtualDeviceDetected`, `rootedOrJailbrokenDeviceDetected`,
`developerOptionsMustBeTurnedOff`, `checkAgain`, `deviceCheckReference`.

New key needed for the tamper reason: `appNotFromOfficialStore`.
