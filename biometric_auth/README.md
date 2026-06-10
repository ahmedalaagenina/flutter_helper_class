# biometric_auth

Local authentication for the app, in two layers:

- **`service/`** — the reusable, **dependency-free** core (`BiometricAuthService`,
  the sealed `BiometricAuthResult`, platform impls). Copy it into any Flutter app
  untouched. See [`service/README.md`](service/README.md).
- **this folder** — thin **app glue** that wires the core to this app's
  localization, theming, DI (`getIt`), storage keys, and navigation.

Everything here is mobile-oriented; the app-lock pieces are wired only on the
non-web build (`MaterialApp.builder`).

## Files

| File | Purpose |
| --- | --- |
| `app_lock_guard.dart` | `AppLockGuard` — full-screen lock that **enforces** biometric/device-credential unlock when the user has enabled it. Also exposes `isAppLockEnabled()`. |
| `app_lock_widget.dart` | `AppLockWidget` — the Settings toggle that turns the lock on/off (runs a biometric check before enabling). |
| `app_lock_prompt.dart` | `AppLockPrompt.maybeShow()` — one-time, opt-in dialog that **invites** the user to enable the lock and flips it on inline. |
| `biometric_sign_gate.dart` | `BiometricSignGate.confirm()` — per-action gate shown before a sensitive operation (e.g. submitting a signature). |

`AppLockGuard` (enforce) and `AppLockPrompt` (acquire) are deliberately separate
responsibilities — see the design note at the bottom.

## Wiring

**1. Register the core service once** (`di/injection_container.dart`):

```dart
getIt.registerLazySingleton<BiometricAuthService>(createBiometricAuthService);
```

**2. Wrap the app with the guard** (`app.dart`, inside `MaterialApp.builder` so
localization/theme/directionality are available; non-web only):

```dart
builder: context.isWeb
    ? null
    : (context, child) => AppLockGuard(
          child: AppUpdaterGuard(/* … */, child: child!),
        ),
```

**3. Trigger the one-time prompt** from an authenticated surface, after the first
frame (`features/dashboard/.../user_dashboard_page.dart`):

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) AppLockPrompt.maybeShow(context);
});
```

**4. Expose the toggle** in Settings (`AppLockWidget`).

## Storage keys (`core/constants/storage_keys.dart`)

| Key | Meaning |
| --- | --- |
| `useBiometricAuth` | The lock is enabled. Read synchronously by `isAppLockEnabled()`. |
| `appLockPromptShown` | The one-time invite has been shown — never offer it again. |

## How `AppLockGuard` behaves

It guards three moments:

1. **Cold start** — if the lock is on, the app opens locked (decided
   synchronously on the first frame, so locked content never flashes) and prompts.
2. **Backgrounding** — content is covered with a blurred overlay immediately, so
   it never leaks into the OS app-switcher snapshot.
3. **Resume** — re-prompts only after the app has been backgrounded longer than
   `lockAfter` (default 10s). Brief excursions (file picker, OAuth, share sheet,
   control center) within the grace window unlock silently. Set
   `lockAfter: Duration.zero` to always re-prompt.

Two subtleties it handles on purpose:

- **No re-prompt loop.** The system biometric sheet itself drives the app through
  `inactive`/`resumed`. While authenticating, all lifecycle events are ignored,
  and after a cancel/fail the guard waits for an explicit *Unlock* tap instead of
  auto-retrying on the dismissed sheet's trailing `resumed`.
- **Correct grace timing.** The background timestamp is stamped only on the
  **first** background event of an episode. The foreground transition is
  `paused → inactive → resumed` on iOS, so that pre-resume `inactive` must not
  reset the clock — otherwise the elapsed time would always read ~0 and the grace
  window would swallow the lock.

If the device can no longer authenticate (`BiometricAuthUnavailable`), the guard
unlocks rather than trapping the user.

## Enable vs enforce — why two components

- `AppLockPrompt` **acquires** a new opt-in. It runs only for users who haven't
  enabled the lock, on an authenticated screen, at most once ever (the
  `appLockPromptShown` flag is set *before* the dialog renders, so an app kill
  mid-dialog can't bring it back). It flips `useBiometricAuth` only after a
  successful biometric check — the user confirms with their own face/finger.
- `AppLockGuard` **enforces** the lock for users who already enabled it, on every
  launch/resume. It sits above the router and has no notion of auth state, which
  is exactly why the *invite* is triggered from the dashboard, not the guard.

## Per-platform setup

See [`service/README.md`](service/README.md) for `local_auth`/WebAuthn
dependencies and the Android (`FlutterFragmentActivity`, `USE_BIOMETRIC`) / iOS
(`NSFaceIDUsageDescription`) requirements.
