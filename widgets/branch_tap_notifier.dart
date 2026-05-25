import 'package:flutter/material.dart';

/// this to control the refresh of the page when the user tap on the same branch (page)
/// also can use it to handle what we need when user tap on any item inside the branch
/// For example, when user tap on the same page, we refresh the data.
/// when user tap on any item inside the branch, we do something else.
/// branch is just a page in the sidebar or in bottom navigation.
///
///
/// Notifies listeners when a navigation branch is tapped.
///
/// Stores the last-tapped branch index so each page can check
/// whether it should refresh its data.
class BranchTapNotifier extends ChangeNotifier {
  int _tappedBranch = -1;
  int _counter = 0;

  int get tappedBranch => _tappedBranch;
  int get counter => _counter;

  void onBranchTapped(int branchIndex) {
    _tappedBranch = branchIndex;
    _counter++;
    notifyListeners();
  }
}

/// [InheritedNotifier] that provides [BranchTapNotifier] to the widget tree.
class BranchTapScope extends InheritedNotifier<BranchTapNotifier> {
  const BranchTapScope({
    super.key,
    required BranchTapNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static BranchTapNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BranchTapScope>();
    assert(scope != null, 'No BranchTapScope found in the widget tree');
    return scope!.notifier!;
  }
}

/// A widget that listens to [BranchTapNotifier] and triggers [onRefresh]
/// whenever [branchIndex] matches the tapped branch.
///
/// Usage in route_configurations.dart:
/// ```dart
/// BranchRefreshWrapper(
///   branchIndex: 1,
///   onRefresh: (ctx) => ctx.read<UsersBloc>().add(UsersRefreshEvent()),
///   child: UsersPage(),
/// )
/// ```
class BranchRefreshWrapper extends StatefulWidget {
  const BranchRefreshWrapper({
    super.key,
    required this.branchIndex,
    required this.onRefresh,
    required this.child,
  });

  final int branchIndex;
  final void Function(BuildContext context) onRefresh;
  final Widget child;

  @override
  State<BranchRefreshWrapper> createState() => _BranchRefreshWrapperState();
}

class _BranchRefreshWrapperState extends State<BranchRefreshWrapper> {
  int _lastSeenCounter = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = BranchTapScope.of(context);
    // Only trigger refresh when the counter actually changed AND branch matches.
    if (notifier.counter != _lastSeenCounter &&
        notifier.tappedBranch == widget.branchIndex) {
      _lastSeenCounter = notifier.counter;
      // Schedule the refresh after the current build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onRefresh(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
