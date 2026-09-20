import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

@immutable
final class BlocPagingState<T> extends PagingStateBase<int, T> {
  BlocPagingState({
    super.pages,
    super.keys,
    super.error,
    super.hasNextPage,
    super.isLoading,
    this.search,
    this.generation = 0,
  });

  final String? search;

  /// Identifies the listing these pages belong to. Incremented by [reset].
  ///
  /// `bloc_concurrency` transformers are scoped per event type, so a refresh
  /// handler cannot cancel a fetch-next handler that is already awaiting the
  /// network. Without a marker, that in-flight response comes back after the
  /// reset and gets appended to the fresh list under its stale page key —
  /// page 3's rows render as page 1 and pages 1–2 are never requested again.
  ///
  /// A page request captures this value before awaiting and compares it after:
  /// if it moved, the response belongs to a listing that no longer exists and
  /// is dropped.
  ///
  /// Deliberately absent from [copyWith] — [reset] is the only thing allowed to
  /// move it, so the marker cannot be forged or accidentally preserved.
  final int generation;

  @override
  BlocPagingState<T> copyWith({
    Defaulted<List<List<T>>?>? pages = const Omit(),
    Defaulted<List<int>?>? keys = const Omit(),
    Defaulted<Object?>? error = const Omit(),
    Defaulted<bool>? hasNextPage = const Omit(),
    Defaulted<bool>? isLoading = const Omit(),
    Defaulted<String?> search = const Omit(),
  }) {
    return BlocPagingState<T>(
      pages: pages is Omit ? this.pages : pages as List<List<T>>?,
      keys: keys is Omit ? this.keys : keys as List<int>?,
      error: error is Omit ? this.error : error,
      hasNextPage: hasNextPage is Omit ? this.hasNextPage : hasNextPage as bool,
      isLoading: isLoading is Omit ? this.isLoading : isLoading as bool,
      search: search is Omit ? this.search : search as String?,
      generation: generation,
    );
  }

  @override
  BlocPagingState<T> reset() => BlocPagingState<T>(
    pages: null,
    keys: null,
    error: null,
    hasNextPage: true,
    isLoading: false,
    search: search,
    generation: generation + 1,
  );

  // PagingStateBase compares only its own fields, so without these overrides a
  // change to `search` or `generation` alone would compare equal, bloc would
  // skip the emit, and the state would never actually move.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlocPagingState<T> &&
          other.search == search &&
          other.generation == generation &&
          super == other);

  @override
  int get hashCode => Object.hash(super.hashCode, search, generation);
}
