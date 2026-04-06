import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kassemha/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:kassemha/features/main/presentation/pages/main_navigation_wrapper.dart';
import 'package:kassemha/injection_container.dart';

import 'routes.dart';

class RouteConfigurations {
  static final RouteConfigurations _instance = RouteConfigurations._internal();

  static RouteConfigurations get instance => _instance;
  static late final GoRouter router;
  static final GlobalKey<NavigatorState> parentNavigatorKey =
      GlobalKey<NavigatorState>();

  factory RouteConfigurations() => _instance;

  RouteConfigurations._internal();

  static void initRouter() {
    final List<RouteBase> routes = [
      GoRoute(
        path: AppRoutesPath.splash,
        name: AppRoutesName.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutesPath.onboarding,
        name: AppRoutesName.onboarding,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<OnboardingCubit>()..load(),
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutesPath.login,
        name: AppRoutesName.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutesPath.signUp,
        name: AppRoutesName.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutesPath.main,
        name: AppRoutesName.main,
        builder: (context, state) => const MainNavigationWrapper(),
      ),

      // // --- Groups ---
      // GoRoute(
      //   path: AppRoutesPath.groupDetails,
      //   name: AppRoutesName.groupDetails,
      //   builder: (context, state) {
      //     final group = RouterHelper.groupFromExtra(state);
      //     if (group == null) return const ErrorPage(); // هندلة الـ Null

      //     return MultiBlocProvider(
      //       providers: [
      //         BlocProvider(
      //           create: (_) =>
      //               getIt<ExpensesBloc>()..add(FetchGroupExpenses(group.id)),
      //         ),
      //         BlocProvider(
      //           create: (_) => getIt<CategoriesBloc>()..add(FetchCategories()),
      //         ),
      //       ],
      //       child: GroupDetailsPage(group: group),
      //     );
      //   },
      // ),
    ];

    router = GoRouter(
      navigatorKey: parentNavigatorKey,
      debugLogDiagnostics: true,
      initialLocation: AppRoutesPath.splash,
      refreshListenable: getIt<AuthRouterRefreshNotifier>(),
      redirect: AppRouteRedirector(
        sessionBloc: getIt(),
        onboardingRepo: getIt(),
        refreshNotifier: getIt(),
      ).redirect,
      routes: routes,
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Route not found: ${state.uri.path}')),
      ),
    );
  }
}
