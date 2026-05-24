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
  });

  final String? search;

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
    );
  }

  @override
  BlocPagingState<T> reset() => BlocPagingState<T>(
    pages: null,
    keys: null,
    error: null,
    hasNextPage: true,
    isLoading: false,
    search: null,
  );
}
