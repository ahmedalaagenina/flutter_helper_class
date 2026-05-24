class PaginationResponse<T> {
  final List<T> items;
  final int? totalItems;
  final int? numberItemPerPage;
  final int? currentPage;
  final int? totalPage;
  PaginationResponse({
    required this.items,
    this.totalItems,
    this.numberItemPerPage,
    this.currentPage,
    this.totalPage,
  });
}

///
//  @override
// Future<PaginationResponse<AppVersionModel>> getAppVersions({
//   required int page,
//   required int limit,
// }) async {
//   final response = await apiService.get(
//     ApiConstant.appVersions,
//     queryParameters: {'page': page, 'limit': limit},
//   );

//   final dataMap =
//       (response.data['data'] as Map?)?.cast<String, dynamic>() ??
//       <String, dynamic>{};
//   final data = (dataMap['data'] as List? ?? const [])
//       .whereType<Map>()
//       .map((item) => AppVersionModel.fromJson(item.cast<String, dynamic>()))
//       .toList();
//   final meta = PaginationMeta.fromJson(dataMap);

//   return PaginationResponse<AppVersionModel>(
//     items: data,
//     currentPage: meta.currentPage,
//     numberItemPerPage: meta.perPage,
//     totalPage: meta.lastPage,
//     totalItems: meta.total,
//   );
// }
