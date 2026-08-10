import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../device_security.dart';
import 'device_integrity_test.dart';

/// A probe whose verdict can change between checks, so "check again" has
/// something to discover.
class MutableProbe implements DeviceProbe {
  MutableProbe({this.paths = const {}, this.delay = Duration.zero});

  Set<String> paths;
  Duration delay;

  @override
  bool get isAndroid => true;
  @override
  bool get isIOS => false;
  @override
  String get operatingSystem => 'android';
  @override
  Map<String, String> get environment => const {};

  @override
  Future<AndroidProbeInfo> androidInfo() =>
      Future.delayed(delay, () => galaxyS23);

  @override
  Future<IosProbeInfo> iosInfo() async => const IosProbeInfo();

  @override
  Future<InstallProbeInfo> installInfo() async => const InstallProbeInfo();

  @override
  Future<bool> isRealDevice() async => true;

  @override
  Future<bool> isJailBroken() async => false;

  @override
  Future<bool> isDeveloperModeEnabled() async => false;

  @override
  Future<bool> isUsbDebuggingEnabled() async => false;

  @override
  Future<bool> pathExists(String path) async => paths.contains(path);
}

/// Stand-in for the host app's auth provider. [isReviewer] is whatever the
/// sign-in response told us — the gate re-reads it, it never asks for it.
class Session extends ChangeNotifier {
  /// Sticky: "somebody has signed in on this install at least once". Signing
  /// out does not clear it, or the login screen would become a permanent hole
  /// in the gate that anyone could reopen by tapping "log out".
  bool hasAccount = false;

  bool isReviewer = false;

  void signIn({bool reviewer = false}) {
    hasAccount = true;
    isReviewer = reviewer;
    notifyListeners();
  }

  void signOut() {
    isReviewer = false;
    notifyListeners();
  }
}

const _appMarker = 'APP CONTENT';

Widget harness({
  bool Function()? allowWhen,
  Listenable? refreshOn,
  WidgetBuilder? pendingBuilder,
}) =>
    MaterialApp(
      builder: (context, child) => DeviceGate(
        allowWhen: allowWhen,
        refreshOn: refreshOn,
        pendingBuilder: pendingBuilder,
        child: child!,
      ),
      home: const Scaffold(body: Text(_appMarker)),
    );

/// Lets the pending probe answer and renders the verdict.
///
/// `pumpAndSettle` is no use here: it stops as soon as nothing schedules a
/// frame, and the gate is parked on a plain `Future` that schedules none. The
/// clock has to be advanced explicitly, then one more frame pumped for the
/// `setState` the completion triggers.
Future<void> settleProbe(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  tearDown(() => DeviceIntegrity.configure(const DeviceIntegrityConfig()));

  testWidgets('app content is not painted before the first verdict lands',
      (tester) async {
    DeviceIntegrity.configure(
      configFor(MutableProbe(delay: const Duration(milliseconds: 300))),
    );

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(
      find.text(_appMarker),
      findsNothing,
      reason: 'a blocked device must never see app content, not even a frame',
    );

    await settleProbe(tester);
    expect(find.text(_appMarker), findsOneWidget);
  });

  testWidgets('pendingBuilder replaces the blank placeholder', (tester) async {
    DeviceIntegrity.configure(
      configFor(MutableProbe(delay: const Duration(milliseconds: 300))),
    );

    await tester.pumpWidget(
      harness(pendingBuilder: (_) => const Text('SPLASH')),
    );
    await tester.pump();

    expect(find.text('SPLASH'), findsOneWidget);
    await settleProbe(tester);
  });

  testWidgets('a blocked device gets the block screen, not the app',
      (tester) async {
    DeviceIntegrity.configure(configFor(
      MutableProbe(paths: {'/data/bluestacks.prop'}),
    ));

    await tester.pumpWidget(harness());
    await settleProbe(tester);

    expect(find.text(_appMarker), findsNothing);
    expect(find.text('Unsupported Device'), findsOneWidget);
  });

  testWidgets('allowWhen lets a blocked device through', (tester) async {
    DeviceIntegrity.configure(configFor(
      MutableProbe(paths: {'/data/bluestacks.prop'}),
    ));

    await tester.pumpWidget(harness(allowWhen: () => true));
    await settleProbe(tester);

    expect(find.text(_appMarker), findsOneWidget);
  });

  testWidgets('refreshOn re-reads allowWhen without re-probing',
      (tester) async {
    var reviewerSignedIn = false;
    final auth = ChangeNotifier();
    addTearDown(auth.dispose);

    DeviceIntegrity.configure(configFor(
      MutableProbe(paths: {'/data/bluestacks.prop'}),
    ));

    await tester.pumpWidget(
      harness(allowWhen: () => reviewerSignedIn, refreshOn: auth),
    );
    await settleProbe(tester);
    expect(find.text(_appMarker), findsNothing);

    reviewerSignedIn = true;
    auth.notifyListeners();
    await settleProbe(tester);

    expect(find.text(_appMarker), findsOneWidget);
  });

  testWidgets('"check again" re-scans and clears a fixed device',
      (tester) async {
    final probe = MutableProbe(paths: {'/data/bluestacks.prop'});
    DeviceIntegrity.configure(configFor(probe));

    await tester.pumpWidget(harness());
    await settleProbe(tester);
    expect(find.text('Unsupported Device'), findsOneWidget);

    // The path cache must not survive a deep re-check, or the button lies.
    probe.paths = const {};
    await tester.tap(find.text('Check again'));
    await settleProbe(tester);

    expect(find.text(_appMarker), findsOneWidget);
  });

  testWidgets('the retry button shows progress while the check runs',
      (tester) async {
    final probe = MutableProbe(paths: {'/data/bluestacks.prop'});
    DeviceIntegrity.configure(configFor(probe));

    await tester.pumpWidget(harness());
    await settleProbe(tester);

    probe.delay = const Duration(milliseconds: 300);
    await tester.tap(find.text('Check again'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await settleProbe(tester);
  });

  group('sign-in decides who gets through', () {
    /// The wiring the README recommends: the gate opens on a fresh install so
    /// the login screen is reachable, and the sign-in response decides what
    /// happens next. The device is probed once, at start-up, and never again.
    Future<Session> emulatorApp(WidgetTester tester) async {
      final session = Session();
      addTearDown(session.dispose);

      DeviceIntegrity.configure(configFor(
        MutableProbe(paths: {'/data/bluestacks.prop'}),
        bypass: () => session.isReviewer,
      ));

      await tester.pumpWidget(harness(
        allowWhen: () => !session.hasAccount,
        refreshOn: session,
      ));
      await settleProbe(tester);
      return session;
    }

    testWidgets('login is reachable on a fresh install, even on an emulator',
        (tester) async {
      await emulatorApp(tester);

      expect(find.text(_appMarker), findsOneWidget);
    });

    testWidgets('an ordinary user is blocked the moment they sign in',
        (tester) async {
      final session = await emulatorApp(tester);

      session.signIn();
      await settleProbe(tester);

      expect(find.text(_appMarker), findsNothing);
      expect(find.text('Unsupported Device'), findsOneWidget);
    });

    testWidgets('a reviewer is let through the moment they sign in',
        (tester) async {
      final session = await emulatorApp(tester);

      session.signIn(reviewer: true);
      await settleProbe(tester);

      expect(find.text(_appMarker), findsOneWidget);
    });

    testWidgets('signing out closes the gate behind a reviewer',
        (tester) async {
      final session = await emulatorApp(tester);
      session.signIn(reviewer: true);
      await settleProbe(tester);
      expect(find.text(_appMarker), findsOneWidget);

      // The regression: the reviewer's pass used to be baked into the cached
      // verdict, so the emulator stayed unlocked for whoever signed in next.
      session.signOut();
      await settleProbe(tester);

      expect(find.text(_appMarker), findsNothing);
    });

    testWidgets('a real device is unaffected by any of it', (tester) async {
      final session = Session();
      addTearDown(session.dispose);

      DeviceIntegrity.configure(configFor(
        MutableProbe(),
        bypass: () => session.isReviewer,
      ));

      await tester.pumpWidget(harness(
        allowWhen: () => !session.hasAccount,
        refreshOn: session,
      ));
      await settleProbe(tester);

      session.signIn();
      await settleProbe(tester);

      expect(find.text(_appMarker), findsOneWidget);
    });
  });

  testWidgets('a bypassed build skips the gate entirely', (tester) async {
    DeviceIntegrity.configure(DeviceIntegrityConfig(
      probe: MutableProbe(paths: const {'/data/bluestacks.prop'}),
      allowDebugBuilds: false,
      bypass: () => true,
    ));

    await tester.pumpWidget(harness());
    await settleProbe(tester);

    expect(find.text(_appMarker), findsOneWidget);
  });
}
