# Shorebird Update Helper

Drop-in over-the-air (OTA) update manager for [Shorebird](https://shorebird.dev).
Self-contained and app-agnostic: it imports nothing from this app, so the folder
can be copied into any Flutter project as-is.

## Quick start

Two steps. That's the whole integration.

```dart
import 'package:sanad_rewards/utils/helpers/shorebird/shorebird.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize before runApp.
  ShorebirdUpdateManager.initialize(navigatorKey: navigatorKey);

  // 2. Optional: only needed if you use RestartWidget.restartApp().
  runApp(RestartWidget(child: MyApp()));
}
```

With no config the manager runs in **silent** mode: it checks 2s after launch
and again on every resume, downloads any patch in the background, and the patch
applies on the next cold start. No UI, no user action, works for signed-out
users on any screen.

> **Do not call `checkForUpdate()` from a screen.** That was the original bug in
> this app: the call lived in `HomeScreen.initState`, so users who never reached
> Home — everyone signed out — never got patched. The manager schedules itself.

## Prerequisites

- `shorebird_code_push: ^2.0.6` in `pubspec.yaml`
- `shorebird.yaml` listed under `flutter: assets:`
- `auto_update: false` in `shorebird.yaml` — this manager is your update path;
  leaving Shorebird's own auto-update on means two updaters racing

`isAvailable` is `false` under `flutter run` / `flutter build`. To test, use
`shorebird run` or `shorebird preview`, otherwise every call is a logged no-op.

## Files

| File | Responsibility |
|---|---|
| `shorebird.dart` | Barrel export — the only import you need |
| `shorebird_update_manager.dart` | Scheduling, throttling, download, retry. No widget code |
| `shorebird_update_prompter.dart` | All UI (banners + dialog). Swap it for your own look |
| `shorebird_update_config.dart` | Every knob, with defaults |
| `shorebird_update_options.dart` | `ShorebirdUpdateMode`, `ShorebirdPromptStyle` |
| `shorebird_update_state.dart` | `ShorebirdUpdatePhase`, `ShorebirdUpdateState` |
| `shorebird_update_strings.dart` | User-facing strings, for localization |
| `restart_widget.dart` | Subtree reset widget (see caveat below) |

## Modes

| Mode | Behaviour |
|---|---|
| `silent` *(default)* | Downloads in the background, never shows UI. Applies on next cold start |
| `notifyWhenReady` | Downloads automatically, then prompts "update ready" |
| `askBeforeDownload` | Prompts before downloading. Use if patches are large |

## Prompt style

`promptStyle` controls how **every** prompt is rendered, so the "update
available" and "update ready" steps always look alike:

| | `ShorebirdPromptStyle.banner` | `ShorebirdPromptStyle.dialog` |
|---|---|---|
| Update available | `MaterialBanner`, Download / Later | `AlertDialog`, Download / Later — dismissible |
| Update ready | `MaterialBanner`, Restart / Later | `AlertDialog`, Restart / Later — **not** dismissible |
| Downloading | `MaterialBanner` + spinner | same |
| Error | `MaterialBanner`, Dismiss | same |

Only the "ready" dialog blocks: declining a download is a normal choice, so a
back gesture there means "Later", while a staged patch is worth one deliberate
answer. Progress and error stay as banners in both styles — they carry no
decision, so a modal would only be in the way.

Dialog style uses `availableTitle` and `readyTitle`; banner style ignores both.

## Full configuration

```dart
ShorebirdUpdateManager.initialize(
  navigatorKey: navigatorKey,
  config: ShorebirdUpdateConfig(
    mode: ShorebirdUpdateMode.notifyWhenReady,
    promptStyle: ShorebirdPromptStyle.banner,
    track: UpdateTrack.stable,

    checkOnStart: true,
    checkOnResume: true,
    startDelay: const Duration(seconds: 2),
    minCheckInterval: const Duration(minutes: 30),

    maxRetries: 2,
    retryBackoff: const Duration(seconds: 5),

    stringsBuilder: (context) => ShorebirdUpdateStrings(
      readyToApply: S.of(context).updateReadyBody,
      restartNow: S.of(context).updateRestartNow,
    ),

    onRestartRequested: () {
      final context = navigatorKey.currentContext;
      if (context != null) RestartWidget.restartApp(context);
    },
    onStateChanged: (state) => debugPrint('$state'),
    onError: (error, stack) =>
        FirebaseCrashlytics.instance.recordError(error, stack),
    logger: AppLog.i,
  ),
);
```

| Field | Default | Notes |
|---|---|---|
| `mode` | `silent` | See table above |
| `promptStyle` | `banner` | Applies to all prompts. Ignored in `silent` |
| `track` | `UpdateTrack.stable` | Also `beta`, `staging`, or `UpdateTrack('custom')` |
| `checkOnStart` | `true` | One check after `startDelay` |
| `checkOnResume` | `true` | Re-check on foreground, subject to `minCheckInterval` |
| `startDelay` | 2s | Keeps the first check off the startup critical path |
| `minCheckInterval` | 30 min | Throttle for automatic checks only |
| `maxRetries` | 2 | Extra download attempts on network failure |
| `retryBackoff` | 5s | Grows linearly: 5s, 10s, … |
| `strings` | English | Static strings. Ignored if `stringsBuilder` is set |
| `stringsBuilder` | `null` | Resolves strings per prompt — use this when localized |
| `onRestartRequested` | `null` | Adds a "Restart now" action to the prompt |
| `onStateChanged` | `null` | Mirrors `ShorebirdUpdateManager.state` |
| `onError` | `null` | Send to Crashlytics/Sentry |
| `logger` | `dart:developer` | Route into your own logger |

## Localization

Pass `stringsBuilder` rather than `strings`. It receives a `BuildContext` and
runs at the moment a prompt is shown, which means two things:

- the app is mounted, so `S.of(context)` is always valid — no need to load
  localizations early in `main()`;
- the prompt follows the language the user is on *right now*, even if they
  switched it after launch.

```dart
stringsBuilder: (context) => ShorebirdUpdateStrings(
  availableTitle: S.of(context).updateAvailableTitle,
  updateAvailable: S.of(context).updateAvailable,
  download: S.of(context).updateDownload,
  downloading: S.of(context).updateDownloading,
  readyTitle: S.of(context).updateReadyTitle,
  readyToApply: S.of(context).updateReadyBody,
  restartNow: S.of(context).updateRestartNow,
  later: S.of(context).updateLater,
  dismiss: S.of(context).updateDismiss,
  downloadFailed: S.of(context).updateDownloadFailed,
),
```

In this app the ten `update*` keys live in `lib/l10n/intl_en.arb` and
`intl_ar.arb`. After editing an ARB, regenerate with:

```sh
dart run intl_utils:generate
```

## Reading state

`ShorebirdUpdateManager.state` is a `ValueNotifier`, so any widget can render it:

```dart
ValueListenableBuilder<ShorebirdUpdateState>(
  valueListenable: ShorebirdUpdateManager.state,
  builder: (context, state, _) {
    if (state.hasPendingUpdate) {
      return Text('Patch ${state.nextPatch} applies on next launch');
    }
    if (state.isBusy) return const CircularProgressIndicator();
    return Text('Patch ${state.currentPatch ?? "—"}');
  },
);
```

`ShorebirdUpdateState` exposes `phase`, `currentPatch`, `nextPatch`, `error`,
plus `isBusy` and `hasPendingUpdate`. Phases: `unavailable`, `idle`, `checking`,
`downloading`, `readyToApply`, `failed`.

## Recipes

**Manual "Check for updates" button** — `force: true` bypasses the throttle:

```dart
final result = await ShorebirdUpdateManager.checkForUpdate(force: true);
if (result.phase == ShorebirdUpdatePhase.idle) showSnack('You are up to date');
```

**Internal beta opt-in** — switches track and re-checks immediately:

```dart
await ShorebirdUpdateManager.setTrack(UpdateTrack.beta);
```

**Show the running patch in a debug/settings screen:**

```dart
final patch = await ShorebirdUpdateManager.getCurrentPatch();
final pending = await ShorebirdUpdateManager.getNextPatch();
```

**Custom update UI** — the manager holds no widget code. Either use `silent` and
drive your own UI off `state`, or edit `ShorebirdUpdatePrompter`; its four
methods (`askToDownload`, `showDownloading`, `showReady`, `showError`) are the
entire surface.

## Restart caveat — read this

**A Shorebird patch is loaded by the engine when the OS process starts.**
Rebuilding the Flutter widget tree does not apply it.

`RestartWidget.restartApp()` swaps a `UniqueKey`, which resets widget state
inside the *same* Dart isolate. It is useful for things like a language switch,
but it does **not** apply a patch. If you wire it to `onRestartRequested`, the
"Restart now" button resets the user's app state and the patch still lands on
the next cold launch.

Options:

1. **Do nothing** (recommended). In `silent` mode the patch applies on the next
   natural launch and the user never notices.
2. **Inform only.** Use `notifyWhenReady` with `onRestartRequested: null`. The
   prompt then says the update applies next launch, with a single dismiss
   action — accurate, no false promise.
3. **Real relaunch.** Add a package that restarts the process and pass it to
   `onRestartRequested`. Note those packages call `exit(0)` on iOS, which App
   Store review has rejected before.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Nothing happens, log says "engine unavailable" | Built with `flutter run`/`flutter build`. Use `shorebird run`/`shorebird preview` |
| Check appears to be skipped | `minCheckInterval` throttle. Pass `force: true` |
| Patch downloads but nothing changes | Expected — it applies on the next **cold** start, not a widget rebuild |
| Banner never appears | `mode` is `silent`, or no `navigatorKey` was passed |
| `initialize() called more than once` | Already wired up; the second call is ignored |
