# Device security

Refuses to run the app on anything that is not a genuine Android phone or
iPhone/iPad: web, Windows, Linux, macOS, Windows Subsystem for Android,
emulators, Android app players (BlueStacks, LDPlayer, Nox, MEmu, MuMu,
Genymotion), and rooted/jailbroken devices.

**No backend required.** The policy behind all of that is compiled into the app
(`SecurityPolicy.defaults`), so the checks run with or without Firestore. The
`security/policy` document is a *remote control* layered on top — it overrides
individual fields — never a prerequisite.

| Check | Ships as | Why |
| --- | --- | --- |
| `blockUnsupportedPlatform` | **on** | web/desktop/WSA — a genuine phone can never report these |
| `blockEmulator` | **on** | the actual threat: app players used to lift content |
| `blockRoot` | **on** | root hides the screenshot and DRM protections |
| `blockDeveloperMode` | **off** | ordinary students enable it on ordinary phones |
| `blockUsbDebugging` | **off** | same, and it lives inside developer options |

```
main()  →  DeviceGuard.start()          runApp  →  DeviceGate reads the verdict
             ├─ cached policy (instant)              ├─ allowed → the app
             └─ read device → verdict                └─ blocked → block screen
```

| File | Responsibility |
| --- | --- |
| `device_signals.dart` | Observes. Reads the device, judges nothing. |
| `device_guard.dart` | Judges + the Firestore policy. The only file with logic. |
| `device_gate.dart` | Shows the app or the block screen. |

**Self-contained is not the same as fail-open**, and this module owes you both:

* *Self-contained* — no policy document means the compiled-in defaults apply.
  A missing backend is a non-event, not an outage and not a lockout.
* *Fail-open* — a channel error or a timeout inside the check itself resolves
  to *allowed*, recorded as a Crashlytics non-fatal. A bug in the detector can
  never cost a student access.

Deleting the policy document reverts every device to the defaults on its next
fetch: the cached copy is dropped, so a policy can always be revoked.

Every `safe_device` getter swallows its own errors and returns `false` — which
reads as "clean" for `isJailBroken` but as "emulator" for `isRealDevice`. So the
reader probes the channel first (`rootDetectionDetails` / `jailbreakDetails`,
the only two members that do *not* swallow errors) and discards the native
answers when that probe throws.

## Firestore: `security/policy`

This document does not exist, so the defaults above are what is running right
now. Create it only to deviate from them — every field you omit keeps its
compiled-in value:

```jsonc
{
  "enabled": true,                  // master kill switch
  "blockUnsupportedPlatform": true, // default true
  "blockEmulator": true,            // default true
  "blockRoot": true,                // default true
  "blockDeveloperMode": false,      // default false — see below
  "blockUsbDebugging": false,       // default false
  "allowedSignals": [],             // retire one signal, e.g. "build:not-physical"
  "allowedUids": []                 // exempt accounts (only after sign-in)
}
```

A field the document omits or misspells keeps its default, so a partial
document is a targeted override and a typo degrades to shipped behaviour rather
than to no protection. Rules:
`match /security/{doc} { allow read: if true; allow write: if false; }`

`blockDeveloperMode` catches any student who once enabled developer options —
on a real Android phone, in normal use. It blocked a genuine TECNO CL7 the first
time this module ran. That is why it ships off: turn it on only with evidence
that piracy is actually coming through that door, and turn it off first when
support tickets arrive.

## Store review

The gate runs **before** sign-in, so `SP.isStoreTest` cannot help a reviewer on
a simulator. Create the document with `enabled: false` before submitting, and
flip it back once the build is live and Google's pre-launch report has run.
Note that *deleting* the document is not an off switch any more — it restores
the defaults, which block emulators.

## Not a substitute for App Check

Client-side detection is a deterrent — a repackaged APK flips the boolean.
Firebase App Check (Play Integrity + App Attest) is what rejects tampered and
emulated clients at the Firestore/Storage boundary.
