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


/// in bloc.dart
//
// AppVersionsState> {
// AppVersionsBloc({
//   required this.getAppVersionsUseCase,
//   this.pageSize = 20,
// }) : super(AppVersionsState.initial()) {
//   on<AppVersionsFetchNextEvent>(_onFetchNext);
// }
//
// Future<void> _onFetchNext(
//   AppVersionsFetchNextEvent event,
//   Emitter<AppVersionsState> emit,
// ) async {
//   final paging = state.paging;
//   if (paging.isLoading || !paging.hasNextPage) return;

//   final pageKey = (paging.keys ?? []).isEmpty ? 1 : paging.nextIntPageKey;

//   emit(state.copyWith(paging: paging.copyWith(isLoading: true, error: null)));

//   final result = await getAppVersionsUseCase(
//     GetAppVersionsParams(page: pageKey, limit: pageSize),
//   );

//   result.fold(
//     (failure) => emit(
//       state.copyWith(
//         paging: state.paging.copyWith(isLoading: false, error: failure.message),
//       ),
//     ),
//     (data) {
//       final items = data.items;
//       final isLastPage =
//           items.length < pageSize ||
//           (data.currentPage ?? 0) == (data.totalPage ?? 0);
//       final updatedPages = [...?state.paging.pages, items];
//       final updatedKeys = [...?state.paging.keys, pageKey];

//       emit(
//         state.copyWith(
//           paging: state.paging.copyWith(
//             isLoading: false,
//             error: null,
//             hasNextPage: !isLastPage,
//             pages: updatedPages,
//             keys: updatedKeys,
//           ),
//         ),
//       );
//     },
//   );
// }


// in bloc_state.dart
  // const AppVersionsState({
  //   required this.paging,
  // });
  // factory AppVersionsState.initial() =>
  //     AppVersionsState(paging: BlocPagingState<AppVersionModel>().reset());

  // final BlocPagingState<AppVersionModel> paging;
