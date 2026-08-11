import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kassemha/core/constants/app_constants.dart';
import 'package:kassemha/core/services/logger_service.dart';

import 'routes.dart';

class AppRouteRedirector {
  AppRouteRedirector({
    required AuthBloc sessionBloc,
    required OnboardingRepo onboardingRepo,
    required AuthRouterRefreshNotifier refreshNotifier,
  }) : _sessionBloc = sessionBloc,
       _onboardingRepo = onboardingRepo,
       _refreshNotifier = refreshNotifier,
       _splashReadyAt = DateTime.now().add(AppConstants.splashMinDisplayTime);

  final AuthBloc _sessionBloc;
  final OnboardingRepo _onboardingRepo;
  final AuthRouterRefreshNotifier _refreshNotifier;
  bool? _seenOnboardingCache;
  bool _splashTimerScheduled = false;
  final DateTime _splashReadyAt;

  Future<String?> redirect(BuildContext context, GoRouterState state) async {
    final authStatus = _sessionBloc.state.status;
    final authState = _sessionBloc.state.actionResult;

    final currentPath = state.matchedLocation;
    final isSplash = currentPath == AppRoutesPath.splash;
    final isOnboarding = currentPath == AppRoutesPath.onboarding;
    final isLogin = currentPath == AppRoutesPath.login;
    final isSignUp = currentPath == AppRoutesPath.signUp;
    final isAuthRoute = isLogin || isSignUp;

    if (_seenOnboardingCache != true) {
      _seenOnboardingCache = await _onboardingRepo.isSeen();
    }
    final hasSeenOnboarding = _seenOnboardingCache ?? false;

    // ── 1. Auth status unknown → hold on splash until resolved
    if (authStatus == AuthStatus.unknown) {
      if (authState.isLoading || authState.isInitial) {
        return isSplash ? null : AppRoutesPath.splash;
      }
    }

    // ── 2. Splash minimum display time not reached → stay on splash
    //    Auth already resolved but animation hasn't finished yet.
    if (isSplash && DateTime.now().isBefore(_splashReadyAt)) {
      _scheduleSplashTimerRefresh();
      return null; // stay on splash
    }

    // ── 3. Onboarding not yet seen → force onboarding
    if (!hasSeenOnboarding) {
      return isOnboarding ? null : AppRoutesPath.onboarding;
    }

    // ── 4. Not authenticated → force login
    if (authStatus == AuthStatus.unauthenticated) {
      return isAuthRoute ? null : AppRoutesPath.login;
    }

    // ── 5. Authenticated → redirect away from auth/splash/onboarding
    if (authStatus == AuthStatus.authenticated) {
      if (isAuthRoute || isSplash || isOnboarding) {
        return AppRoutesPath.main;
      }
    }

    return null;
  }

  /// Schedules a single delayed refresh so the router re-evaluates
  /// after the splash minimum display time has elapsed.
  void _scheduleSplashTimerRefresh() {
    if (_splashTimerScheduled) return;
    _splashTimerScheduled = true;

    final remaining = _splashReadyAt.difference(DateTime.now());
    Future.delayed(remaining, () {
      _refreshNotifier.notify();
    });
  }
}


/// simple one 
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:idara_tracking_app/config/router/app_routes.dart';
// import 'package:idara_tracking_app/config/router/go_router_refresh_stream.dart';
// import 'package:idara_tracking_app/core/constants/app_constants.dart';
// import 'package:idara_tracking_app/core/util/app_log.dart';
// import 'package:idara_tracking_app/features/auth/presentation/bloc/auth_bloc.dart';
// import 'package:injectable/injectable.dart';

// @lazySingleton
// class AppRouteRedirector {
//   AppRouteRedirector(this._authBloc, this._refreshNotifier);

//   final AuthBloc _authBloc;
//   final AppRouterRefreshNotifier _refreshNotifier;
//   DateTime? _splashVisibleUntil;
//   DateTime? _splashGiveUpAt;
//   final Set<DateTime> _scheduledWakes = {};

//   String? redirect(BuildContext context, GoRouterState state) {
//     final status = _authBloc.state.status;
//     final location = state.matchedLocation;

//     final isSplash = location == AppRoutesPath.splash;
//     final isPublic = AppRoutesPath.publicPaths.contains(location);
//     if (status == AuthStatus.unknown && !isSplash) {
//       return AppRoutesPath.splash;
//     }

//     if (isSplash) {
//       final now = DateTime.now();
//       final showUntil = _splashVisibleUntil ??= now.add(
//         AppConstants.splashMinDisplayTime,
//       );
//       final giveUpAt = _splashGiveUpAt ??= now.add(AppConstants.splashMaxWait);

//       if (status == AuthStatus.unknown) {
//         if (!now.isBefore(giveUpAt)) {
//           AppLog.w(
//             '[AppRouteRedirector] Session unresolved after '
//             '${AppConstants.splashMaxWait.inSeconds}s — falling back to login.',
//           );
//           return AppRoutesPath.login;
//         }

//         _wakeAt(giveUpAt);
//         return null;
//       }

//       if (now.isBefore(showUntil)) {
//         _wakeAt(showUntil);
//         return null;
//       }
//     }

//     if (status == AuthStatus.unauthenticated) {
//       return isPublic ? null : AppRoutesPath.login;
//     }

//     if (isSplash || isPublic) return AppRoutesPath.map;

//     return null;
//   }

//   void _wakeAt(DateTime instant) {
//     if (!_scheduledWakes.add(instant)) return;

//     final remaining = instant.difference(DateTime.now());
//     Future<void>.delayed(
//       remaining.isNegative ? Duration.zero : remaining,
//       _refreshNotifier.notify,
//     );
//   }
// }

