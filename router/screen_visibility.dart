import 'package:flutter/material.dart';
import 'package:idara_tracking_app/config/router/route_configurations.dart';

/// Tells a screen when another page covers it, and when it comes back.
///
/// ## Why this exists
///
/// A pushed route does not dispose the screen underneath — it is still mounted,
/// still holding its blocs, still running its timers and tickers. It simply
/// cannot be seen. So a screen that polls the network, animates, or holds a
/// camera keeps doing all of it behind whatever the operator opened, spending
/// battery and mobile data on pixels nobody is looking at.
///
/// Flutter's answer is [RouteAware] plus a [RouteObserver], but wiring it up is
/// four things a screen has to get right every time: subscribe against the
/// right route, unsubscribe on dispose, and implement two of `RouteAware`'s
/// four callbacks while ignoring the other two. This mixin does all of that so
/// a screen only writes the part that is actually about the screen.
///
/// ## Using it
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ScreenVisibility {
///   @override
///   void onCovered() => _stopExpensiveWork();
///
///   @override
///   void onRevealed() => _resumeExpensiveWork();
/// }
/// ```
///
/// That is the whole contract. [isCovered] is also available for code that has
/// to make a decision rather than react to an edge — a lifecycle handler that
/// must not resume work while something else is on top, for instance.
///
/// ⚠️ **`onCovered` fires as the push begins, not when the animation ends.**
/// `RouteAware.didPushNext` is synchronous with the push, so this screen may
/// still be partly visible behind the incoming transition. That is the right
/// moment to stop network work; it is the wrong moment to tear down anything
/// the operator would see vanish mid-slide.
///
/// ⛔ **Bottom sheets do not count as covering.** The shared observer is typed
/// to `PageRoute<void>` and a sheet is a `PopupRoute`, so opening one leaves
/// this screen running — which is correct, since the map is still visible
/// behind it. See [RouteConfigurations.routeObserver] for why that type matters.
mixin ScreenVisibility<T extends StatefulWidget> on State<T>
    implements RouteAware {
  bool _isCovered = false;

  /// Whether a full page is currently sitting on top of this screen.
  bool get isCovered => _isCovered;

  /// Another page was pushed over this screen. Stop what cannot be seen.
  void onCovered() {}

  /// The covering page was popped. This screen is visible again.
  void onRevealed() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ⛔ Must be a `PageRoute<void>`, matching the observer's type argument.
    // `RouteObserver` only notifies when the pushed route *and* the covered one
    // both match, so subscribing anything else silently never fires.
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      RouteConfigurations.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Safe to call even when the subscribe above never happened.
    RouteConfigurations.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    _isCovered = true;
    onCovered();
  }

  @override
  void didPopNext() {
    _isCovered = false;
    onRevealed();
  }

  /// This screen itself was pushed. Its `initState` already covers that.
  @override
  void didPush() {}

  /// This screen itself was popped. Its `dispose` already covers that.
  @override
  void didPop() {}
}
